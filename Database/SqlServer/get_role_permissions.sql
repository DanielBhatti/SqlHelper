;with sql_roles as
(
select   
role_name = roleprinc.name,
role_authentication = roleprinc.authentication_type_desc,
permission_type = perm.permission_name,       
permission_state = perm.state_desc,       
object_type = obj.type_desc,  
object_name = object_name(perm.major_id),
object_class = perm.class_desc,
object_schema_name = object_schema_name(perm.major_id),
grant_statement = perm.state_desc + ' ' + perm.permission_name + ' ON ' + quotename(object_schema_name(perm.major_id)) + '.' + quotename(object_name(perm.major_id)) + ' TO ' + quotename(roleprinc.name) COLLATE DATABASE_DEFAULT,
revoke_statement = 'REVOKE ' + perm.permission_name + ' ON ' + quotename(object_schema_name(perm.major_id)) + '.' + quotename(object_name(perm.major_id)) + ' TO ' + quotename(roleprinc.name COLLATE DATABASE_DEFAULT)

from sys.database_principals roleprinc
left join sys.database_permissions perm on perm.grantee_principal_id = roleprinc.principal_id                
left join sys.objects obj ON obj.object_id = perm.major_id
)
select
*
from sql_roles
where
role_name like '%eaglewriter%'