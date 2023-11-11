using System;
using System.Collections.Generic;
using System.Text;

namespace SqlHelper
{
    public interface ISqlTemplate
    {
        string Template { get; }
        string VariablePrefix { get; }
        string[] Variables { get; }
        SqlType[] VariableTypes { get; }
        string[] Arguments { get; }
    }
}
