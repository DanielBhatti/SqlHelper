using System;
using System.Collections.Generic;
using System.Text;

namespace SqlHelper
{
    public class SqlTemplate : ISqlTemplate
    {
        public string Template { get; }
        public string VariablePrefix { get; }
        public string[] Variables { get; }
        public SqlType[] VariableTypes { get; }
        public string[] Arguments { get; }

        public SqlTemplate(string template, string variablePrefix = "@")
        {
            Template = template;
            VariablePrefix = variablePrefix;
        }

        public string Replace()
        {

        }
    }
}
