-- ============================================================
-- Kloud Kart: Persistent data-quality exception register
-- Stores first/last detection, repeat counts and review status.
-- Safe to rerun; preserves existing exception history.
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.data_quality_exceptions (
    exception_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_table TEXT NOT NULL,
    source_record_id TEXT NOT NULL,
    issue_type TEXT NOT NULL,
    original_values JSONB NOT NULL,

    first_detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    detection_count BIGINT NOT NULL DEFAULT 1,

    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'investigating', 'resolved')),

    resolved_at TIMESTAMPTZ,
    resolution_note TEXT,

    CONSTRAINT uq_data_quality_exception
        UNIQUE (source_table, source_record_id, issue_type)
);

CREATE INDEX IF NOT EXISTS idx_dq_exceptions_status
    ON public.data_quality_exceptions (status);

CREATE INDEX IF NOT EXISTS idx_dq_exceptions_type
    ON public.data_quality_exceptions (issue_type);


CREATE OR REPLACE FUNCTION record_data_quality_exception(
    p_source_table TEXT,
    p_source_record_id TEXT,
    p_issue_type TEXT,
    p_original_values JSONB
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.data_quality_exceptions AS dq (
        source_table,
        source_record_id,
        issue_type,
        original_values
    )
    VALUES (
        p_source_table,
        p_source_record_id,
        p_issue_type,
        p_original_values
    )
    ON CONFLICT (source_table, source_record_id, issue_type)
    DO UPDATE SET
        last_detected_at = NOW(),
        detection_count = dq.detection_count + 1,
        status = CASE
            WHEN dq.status = 'resolved'
            THEN 'open'
            ELSE dq.status
        END,
        resolved_at = CASE
            WHEN dq.status = 'resolved'
            THEN NULL
            ELSE dq.resolved_at
        END,
        resolution_note = CASE
            WHEN dq.status = 'resolved'
            THEN NULL
            ELSE dq.resolution_note
        END;
END;
$$;

-- Upgrade an existing installation without losing exception history.
ALTER TABLE public.data_quality_exceptions
    ALTER COLUMN detection_count TYPE BIGINT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.data_quality_exceptions'::regclass
          AND conname = 'ck_data_quality_detection_count'
    ) THEN
        ALTER TABLE public.data_quality_exceptions
            ADD CONSTRAINT ck_data_quality_detection_count
            CHECK (detection_count > 0) NOT VALID;
    END IF;
END;
$$;

COMMIT;

REVOKE ALL ON FUNCTION public.record_data_quality_exception(text, text, text, jsonb) FROM PUBLIC;
