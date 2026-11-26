CREATE TABLE IF NOT EXISTS data_quality_exceptions (
    exception_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_table TEXT NOT NULL,
    source_record_id TEXT NOT NULL,
    issue_type TEXT NOT NULL,
    original_values JSONB NOT NULL,

    first_detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    detection_count INTEGER NOT NULL DEFAULT 1,

    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'investigating', 'resolved')),

    resolved_at TIMESTAMPTZ,
    resolution_note TEXT,

    CONSTRAINT uq_data_quality_exception
        UNIQUE (source_table, source_record_id, issue_type)
);

CREATE INDEX IF NOT EXISTS idx_dq_exceptions_status
    ON data_quality_exceptions (status);

CREATE INDEX IF NOT EXISTS idx_dq_exceptions_type
    ON data_quality_exceptions (issue_type);


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
    INSERT INTO data_quality_exceptions (
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
        detection_count = data_quality_exceptions.detection_count + 1,
        status = CASE
            WHEN data_quality_exceptions.status = 'resolved'
            THEN 'open'
            ELSE data_quality_exceptions.status
        END,
        resolved_at = CASE
            WHEN data_quality_exceptions.status = 'resolved'
            THEN NULL
            ELSE data_quality_exceptions.resolved_at
        END,
        resolution_note = CASE
            WHEN data_quality_exceptions.status = 'resolved'
            THEN NULL
            ELSE data_quality_exceptions.resolution_note
        END;
END;
$$;
