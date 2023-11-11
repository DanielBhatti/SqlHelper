declare @sql nvarchar(max) = ''
select @sql = @sql +  'exec sp_refreshview ''' + schema_name(schema_id) + '.' + name + ''';' + char(13) + char(10) 
from sys.objects as so 
where so.type = 'v' 

select @sql