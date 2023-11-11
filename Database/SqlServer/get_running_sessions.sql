select
query_text = sqltext.text,
ses.login_name,
req.session_id,
req.start_time,
req.blocking_session_id,
req.percent_complete,
req.cpu_time,
req.total_elapsed_time,
req.reads,
req.writes,
req.status,
req.command,
database_name = db_name(req.database_id),
req.wait_type,
req.wait_time,
req.wait_resource
from sys.dm_exec_requests as req
inner join sys.dm_exec_sessions AS ses ON req.session_id = ses.session_id
cross apply sys.dm_exec_sql_text(req.sql_handle) as sqltext
--order by blocking_session_id, session_id
order by total_elapsed_time desc