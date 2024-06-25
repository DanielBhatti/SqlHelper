DECLARE @json NVARCHAR(MAX) = (
	SELECT top 1 *
	FROM msr.vw_RepurchaseRequests
	FOR JSON AUTO
)

select @json = replace(@json, '"' + COLUMN_NAME + '":', COLUMN_NAME + ':')
from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME = 'vw_RepurchaseRequests'

select @json = REPLACE(@json, COLUMN_NAME + ':', dbo.SnakeToPascalCase(COLUMN_NAME) + ':')
from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME = 'vw_RepurchaseRequests'

--select @json = REPLACE(@json, COLUMN_NAME + ':', dbo.SnakeToPascalCase(COLUMN_NAME) + ':')
--from INFORMATION_SCHEMA.COLUMNS
--where TABLE_NAME = 'vw_RepurchaseRequests'
--and DATA_TYPE like 'date%'

set @json = REPLACE(@json, ':', '=')

select @json

