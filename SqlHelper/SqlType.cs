using System;
using System.Collections.Generic;
using System.Text;

namespace SqlHelper
{
    public enum SqlType
    {
        // Standard types
        // Prefaced by Sql since some are keywords (e.g. int and char)
        SqlChar,
        SqlVarchar,
        SqlText,
        SqlNChar,
        SqlNVarchar,
        SqlNText,
        SqlDate,
        SqlDateTime,
        SqlFloat,
        SqlReal,
        SqlBigInt,
        SqlNumeric,
        SqlBit,
        SqlSmallInt,
        SqlDecimal,
        SqlInt,
        SqlTinyInt,
        // Non-standard "types" for the purposes of this library
        SqlTable,
        SqlRow,
        SqlColumn
    }
}
