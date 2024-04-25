set transaction isolation level read uncommitted
-- note that if the routine definition spans more than 1 column, you'll have to remove whitespace when copying
-- default setting will add a tab between column values
declare @object_schema varchar(255) = ''
declare @object_name varchar(255) = 'vw_Msr'

--- Don't modify anything beyond this line

-- max number of characters displayed in results window for varchars in SQL Server Management Studio
declare @v_max int = 43679

select
object_schema_name(object_id),
object_name(object_id),
definition_page_0 = substring(definition, 0, @v_max),
definition_page_1 = substring(definition, 1 * @v_max, @v_max),
definition_page_2 = substring(definition, 2 * @v_max, @v_max),
definition_page_3 = substring(definition, 3 * @v_max, @v_max),
definition_page_4 = substring(definition, 4 * @v_max, @v_max),
definition_page_5 = substring(definition, 5 * @v_max, @v_max),
definition_page_6 = substring(definition, 6 * @v_max, @v_max),
definition_page_7 = substring(definition, 7 * @v_max, @v_max),
definition_page_8 = substring(definition, 8 * @v_max, @v_max),
definition_page_9 = substring(definition, 9 * @v_max, @v_max),
definition_page_10 = substring(definition, 10 * @v_max, @v_max)
from sys.sql_modules with (nolock)
where
object_schema_name(object_id) like '%' + @object_schema + '%'
and object_name(object_id) like '%' + @object_name + '%'
order by
object_schema_name(object_id),
object_name(object_id)