-- Read-only projections for the legacy OpenCode `message` and `part` schema.
-- These are retained-local-history observations, not account billing or quota.
-- Run with a read-only SQLite connection. Do not sum message + step + session usage.

SELECT
  json_extract(data, '$.providerID') AS provider,
  json_extract(data, '$.modelID') AS model,
  COUNT(*) AS assistant_messages,
  COUNT(json_extract(data, '$.tokens')) AS messages_with_tokens,
  SUM(json_extract(data, '$.tokens.input')) AS input_tokens,
  SUM(json_extract(data, '$.tokens.output')) AS output_tokens,
  SUM(json_extract(data, '$.tokens.reasoning')) AS reasoning_tokens,
  SUM(json_extract(data, '$.tokens.cache.read')) AS cache_read_tokens,
  SUM(json_extract(data, '$.tokens.cache.write')) AS cache_write_tokens,
  SUM(json_extract(data, '$.cost')) AS recorded_cost
FROM message
WHERE json_extract(data, '$.role') = 'assistant'
GROUP BY 1, 2;

-- Uses the process/system local timezone, attributed to message creation.
-- A production collector should use its explicit reporting timezone and bounds.
-- A missing day is not proof of zero account activity. No COALESCE for missing usage.
SELECT
  date(json_extract(data, '$.time.created') / 1000.0, 'unixepoch', 'localtime') AS local_day,
  COUNT(*) AS assistant_messages,
  COUNT(json_extract(data, '$.tokens')) AS messages_with_tokens,
  SUM(json_extract(data, '$.tokens.input')) AS input_tokens,
  SUM(json_extract(data, '$.tokens.output')) AS output_tokens,
  SUM(json_extract(data, '$.tokens.reasoning')) AS reasoning_tokens,
  SUM(json_extract(data, '$.tokens.cache.read')) AS cache_read_tokens,
  SUM(json_extract(data, '$.tokens.cache.write')) AS cache_write_tokens,
  SUM(json_extract(data, '$.cost')) AS recorded_cost
FROM message
WHERE json_extract(data, '$.role') = 'assistant'
GROUP BY 1
ORDER BY 1;

SELECT
  json_extract(data, '$.state.status') AS status,
  COUNT(*) AS tool_calls
FROM part
WHERE json_extract(data, '$.type') = 'tool'
GROUP BY 1;
