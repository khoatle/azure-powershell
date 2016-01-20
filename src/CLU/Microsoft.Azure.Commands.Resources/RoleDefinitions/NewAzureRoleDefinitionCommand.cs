﻿// ----------------------------------------------------------------------------------
//
// Copyright Microsoft Corporation
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// ----------------------------------------------------------------------------------

using System.IO;
using System.Management.Automation;
using Microsoft.Azure.Commands.Resources.Models;
using Microsoft.Azure.Commands.Resources.Models.ActiveDirectory;
using Microsoft.Azure.Commands.Resources.Models.Authorization;
using Microsoft.Azure.Commands.Utilities.Common;
using Newtonsoft.Json;

namespace Microsoft.Azure.Commands.Resources
{
    /// <summary>
    /// Creates a new role definition.
    /// </summary>
    [Cmdlet(VerbsCommon.New, "AzureRmRoleDefinition"), OutputType(typeof(PSRoleDefinition))]
    [CliCommandAlias("resource role definition create")]
    public class NewAzureRoleDefinitionCommand : ResourcesBaseCmdlet
    {
        [ValidateNotNullOrEmpty]
        [Parameter(Position = 0, Mandatory = true, ParameterSetName = ParameterSet.InputFile, HelpMessage = "File name containing a single role definition.")]
        public string InputFile { get; set; }

        [ValidateNotNullOrEmpty]
        [Parameter(Position = 0, Mandatory = true, ParameterSetName = ParameterSet.RoleDefinition, HelpMessage = "Role definition.")]
        public PSRoleDefinition Role { get; set; }

        protected override void ProcessRecord()
        {
            PSRoleDefinition role = null;
            if (!string.IsNullOrEmpty(InputFile))
            {
                string fileName = InputFile;
                if (!(new FileInfo(fileName)).Exists)
                {
                    throw new PSArgumentException(string.Format("File {0} does not exist", fileName));
                }

                try
                {
                    role = JsonConvert.DeserializeObject<PSRoleDefinition>(File.ReadAllText(fileName));
                }
                catch (JsonException)
                {
                    WriteVerbose("Deserializing the input role definition failed.");
                    throw;
                }
            }
            else
            {
                role = Role;
            }

            WriteObject(PoliciesClient.CreateRoleDefinition(role));
        }
    }
}
