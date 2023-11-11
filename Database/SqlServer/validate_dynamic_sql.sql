create function dbo.ValidateDynamicSql(@sql varchar(max))
returns varchar(max)
as
begin
    if exists (
            select top 1 error_number
            from sys.dm_exec_describe_first_result_set(@sql,null,0)
            where error_number is not null
            ) 
            begin
            declare @output varchar(max) = ''
            select @output += cast(column_ordinal as varchar(3)) + ': ' + error_message + char(13) + char(10)
            from sys.dm_exec_describe_first_result_set(@sql,null,0)
            order by column_ordinal asc
            return @output
            end
    
    return 'Success'
end