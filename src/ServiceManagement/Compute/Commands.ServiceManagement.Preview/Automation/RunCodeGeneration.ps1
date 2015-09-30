﻿# ----------------------------------------------------------------------------------
#
# Copyright Microsoft Corporation
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------------------------------------------------------------

# This script is to generate a set of operation and parameter cmdlets that
# are mapped from the source client library. 
#
# For example, 'ComputeManagementClient.VirtualMachines.Start()' would be
# 'Invoke-AzureVirtualMachineStartMethod'.
#
# It's also possible to map the actual verb from function to cmdlet, e.g.
# the above example would be 'Start-AzureVirtualMachine', but to keep it
# simple and consistent, we would like to use the generic verb.

[CmdletBinding()]
param(
    # The folder that contains the source DLL, and all its dependency DLLs.
    [Parameter(Mandatory = $true)]
    [string]$dllFolder,

    # The target output folder, and the generated files would be organized in
    # the sub-folder called 'Generated'.
    [Parameter(Mandatory = $true)]
    [string]$outFolder,
    
    # The namespace of the Compute client library
    [Parameter(Mandatory = $true)]
    [string]$client_library_namespace = 'Microsoft.WindowsAzure.Management.Compute',

    # The base cmdlet from which all automation cmdlets derive
    [Parameter(Mandatory = $true)]
    [string]$baseCmdletFullName = 'Microsoft.WindowsAzure.Commands.Utilities.Common.ServiceManagementBaseCmdlet',

    # The property field to access the client wrapper class from the base cmdlet
    [Parameter(Mandatory = $true)]
    [string]$base_class_client_field = 'ComputeClient',
    
    # Cmdlet Code Generation Flavor
    # 1. Invoke (default) that uses Invoke as the verb, and Operation + Method (e.g. VirtualMachine + Get)
    # 2. Verb style that maps the method name to a certain common PS verb (e.g. CreateOrUpdate -> New)
    [Parameter(Mandatory = $false)]
    [string]$cmdletFlavor = 'Invoke',

    # CLI Command Code Generation Flavor
    [Parameter(Mandatory = $false)]
    [string[]]$cliCommandFlavor = 'Verb',

    # The filter of operation name for code generation
    # e.g. "VirtualMachineScaleSet","VirtualMachineScaleSetVM"
    [Parameter(Mandatory = $false)]
    [string[]]$operationNameFilter = $null
)

$new_line_str = "`r`n";
$verbs_common_new = "VerbsCommon.New";
$verbs_lifecycle_invoke = "VerbsLifecycle.Invoke";
$client_model_namespace = $client_library_namespace + '.Models';

$common_verb_mapping =
@{
"CreateOrUpdate" = "New";
"Get" = "Get";
"List" = "Get";
"Delete" = "Remove";
"Deallocate" = "Stop";
"PowerOff" = "Stop";
"Start" = "Start";
"Restart" = "Restart";
"Capture" = "Save";
"Update" = "Update";
};

$common_noun_mapping =
@{
"VirtualMachine" = "VM";
"ScaleSet" = "SS";
};

$all_return_type_names = @();

Write-Verbose "=============================================";
Write-Verbose "Input Parameters:";
Write-Verbose "DLL Folder            = $dllFolder";
Write-Verbose "Out Folder            = $outFolder";
Write-Verbose "Client NameSpace      = $client_library_namespace";
Write-Verbose "Model NameSpace       = $client_model_namespace";
Write-Verbose "Base Cmdlet Full Name = $baseCmdletFullName";
Write-Verbose "Base Client Name      = $base_class_client_field";
Write-Verbose "Cmdlet Flavor         = $cmdletFlavor";
Write-Verbose "Operation Name Filter = $operationNameFilter";
Write-Verbose "=============================================";
Write-Verbose "${new_line_str}";

$code_common_namespace = ($client_library_namespace.Replace('.Management.', '.Commands.')) + '.Automation';
$code_model_namespace = ($client_library_namespace.Replace('.Management.', '.Commands.')) + '.Automation.Models';

$code_common_usings = @(
    'System',
    'System.Collections.Generic',
    'System.Linq',
    'System.Management.Automation',
    'Microsoft.Azure'
);

$code_common_header =
@"
// 
// Copyright (c) Microsoft and contributors.  All rights reserved.
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//   http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// 
// See the License for the specific language governing permissions and
// limitations under the License.
// 

// Warning: This code was generated by a tool.
// 
// Changes to this file may cause incorrect behavior and will be lost if the
// code is regenerated.
"@;

function Get-SortedUsingsCode
{
    $list_of_usings = @() + $code_common_usings + $client_library_namespace + $client_model_namespace + $code_model_namespace;
    $sorted_usings = $list_of_usings | Sort-Object -Unique | foreach { "using ${_};" };

    $text = [string]::Join($new_line_str, $sorted_usings);

    return $text;
}

$code_using_strs = Get-SortedUsingsCode;

function Get-NormalizedName
{
    param(
        # Sample: 'vmName' => 'VMName', 'resourceGroup' => 'ResourceGroup', etc.
        [Parameter(Mandatory = $True)]
        [string]$inputName
    )

    if ([string]::IsNullOrEmpty($inputName))
    {
        return $inputName;
    }

    if ($inputName.StartsWith('vm'))
    {
        $outputName = 'VM' + $inputName.Substring(2);
    }
    else
    {
        [char]$firstChar = $inputName[0];
        $firstChar = [System.Char]::ToUpper($firstChar);
        $outputName = $firstChar + $inputName.Substring(1);
    }

    return $outputName;
}

function Get-CliNormalizedName
{
    # Sample: 'VMName' to 'vmName', 'VirtualMachine' => 'virtualMachine', 'ResourceGroup' => 'resourceGroup', etc.
    param(
        [Parameter(Mandatory = $True)]
        [string]$inName
    )

    if ([string]::IsNullOrEmpty($inName))
    {
        return $inName;
    }

    if ($inName.StartsWith('VM'))
    {
        $outName = 'vm' + $inName.Substring(2);
    }
    elseif ($inName.StartsWith('IP'))
    {
        $outName = 'ip' + $inName.Substring(2);
    }
    else
    {
        [char]$firstChar = $inName[0];
        $firstChar = [System.Char]::ToLower($firstChar);
        $outName = $firstChar + $inName.Substring(1);
    }

    return $outName;
}


function Get-CliCategoryName
{
    # Sample: 'VirtualMachineScaleSetVM' => 'vmssvm', 'VirtualMachineScaleSet' => 'vmss', etc.
    param(
        [Parameter(Mandatory = $True)]
        [string]$inName
    )

    if ($inName -eq 'VirtualMachineScaleSet')
    {
        $outName = 'vmss';
    }
    elseif ($inName -eq 'VirtualMachineScaleSetVM')
    {
        $outName = 'vmssvm';
    }
    else
    {
        $outName = Get-CliNormalizedName $inName;
    }

    return $outName;
}


function Get-CliOptionName
{
    # Sample: 'VMName' to 'vmName', 'VirtualMachine' => 'virtualMachine', 'ResourceGroup' => 'resourceGroup', etc.
    param(
        [Parameter(Mandatory = $True)]
        [string]$inName
    )

    if ([string]::IsNullOrEmpty($inName))
    {
        return $inName;
    }

    [string]$varName = Get-CliNormalizedName $inName;
    [string]$outName = $null;

    $i = 0;
    while ($i -lt $varName.Length)
    {
        if ($i -eq 0 -or [char]::IsUpper($varName[$i]))
        {
            if ($i -gt 0)
            {
                # Sample: "parameter-..."
                $outName += '-';
            }

            [string[]]$abbrWords = @('VM', 'IP');
            $matched = $false;
            foreach ($matchedAbbr in $abbrWords)
            {
                if ($varName.Substring($i) -like ("${matchedAbbr}*"))
                {
                    $matched = $true;
                    break;
                }
            }

            if ($matched)
            {
                $outName += $matchedAbbr.ToLower();
                $i = $i + $matchedAbbr.Length;
            }
            else
            {
                $j = $i + 1;
                while (($j -lt $varName.Length) -and [char]::IsLower($varName[$j]))
                {
                    $j++;
                }

                $outName += $varName.Substring($i, $j - $i).ToLower();
                $i = $j;
            }
        }
        else
        {
            $i++;
        }
    }

    return $outName;
}

function Get-NormalizedTypeName
{
    param(
        # Sample: 'System.String' => 'string', 'System.Boolean' => bool, etc.
        [Parameter(Mandatory = $True)]
        [string]$inputName
    )

    if ([string]::IsNullOrEmpty($inputName))
    {
        return $inputName;
    }

    $outputName = $inputName;
    $client_model_namespace_prefix = $client_model_namespace + '.';

    if ($inputName -eq 'System.String')
    {
        $outputName = 'string';
    }
    elseif ($inputName -eq 'System.Boolean')
    {
        $outputName = 'bool';
    }
    elseif ($inputName -eq 'System.DateTime')
    {
        return 'DateTime';
    }
    elseif ($inputName -eq 'System.Int32')
    {
        return 'int';
    }
    elseif ($inputName -eq 'System.UInt32')
    {
        return 'uint';
    }
    elseif ($inputName.StartsWith($client_model_namespace_prefix))
    {
        $outputName = $inputName.Substring($client_model_namespace_prefix.Length);
    }

    $outputName = $outputName.Replace('+', '.');

    return $outputName;
}

function Get-ConstructorCodeByNormalizedTypeName
{
    param(
        # Sample: 'string' => 'string.Empty', 'HostedServiceCreateParameters' => 'new HostedServiceCreateParameters()', etc.
        [Parameter(Mandatory = $True)]
        [string]$inputName
    )

    if ([string]::IsNullOrEmpty($inputName))
    {
        return 'null';
    }

    if ($inputName -eq 'string')
    {
        $outputName = 'string.Empty';
    }
    else
    {
        if ($inputName.StartsWith($client_model_namespace + "."))
        {
            $inputName = $inputName.Replace($client_model_namespace + ".", '');
        }
        elseif ($inputName.StartsWith('System.Collections.Generic.'))
        {
            $inputName = $inputName.Replace('System.Collections.Generic.', '');
        }

        $outputName = 'new ' + $inputName + "()";
    }

    return $outputName;
}

function Get-OperationShortName
{
    param(
        # Sample #1: 'IVirtualMachineOperations' => 'VirtualMachine'
        # Sample #2: 'IDeploymentOperations' => 'Deployment'
        [Parameter(Mandatory = $True)]
        [string]$opFullName
    )

    $prefix = 'I';
    $suffix = 'Operations';
    $opShortName = $opFullName;

    if ($opFullName.StartsWith($prefix) -and $opShortName.EndsWith($suffix))
    {
        $lenOpShortName = ($opShortName.Length - $prefix.Length - $suffix.Length);
        $opShortName = $opShortName.Substring($prefix.Length, $lenOpShortName);
    }

    return $opShortName;
}

function Match-OperationFilter
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$operation_full_name,

        [Parameter(Mandatory = $true)]
        $operation_name_filter)

    if ($operation_name_filter -eq $null)
    {
        return $true;
    }

    if ($operation_name_filter -eq '*')
    {
        return $true;
    }

    $op_short_name = Get-OperationShortName $operation_full_name;
    if ($operation_name_filter -ccontains $op_short_name)
    {
        return $true;
    }

    return $false;
}

# Get Filtered Operation Types from all DLL Types
function Get-FilteredOperationTypes
{
    param(
        [Parameter(Mandatory = $true)]
        $all_assembly_types,

        [Parameter(Mandatory = $true)]
        $dll_name,
        
        [Parameter(Mandatory = $false)]
        $operation_name_filter = $null
    )

    $op_types = $all_assembly_types | where { $_.Namespace -eq $dll_name -and $_.Name -like 'I*Operations' };

    Write-Verbose 'All Operation Types:';
    foreach ($op_type in $op_types)
    {
        Write-Verbose ($op_type.Namespace + ', ' + $op_type.Name);
    }

    $op_filtered_types = $op_types;
    if ($operation_name_filter -ne $null)
    {
        $op_filtered_types = $op_filtered_types | where { Match-OperationFilter $_.Name $operation_name_filter };
    }

    Write-Verbose ('Operation Name Filter : "' + $operation_name_filter + '"');
    Write-Verbose 'Filtered Operation Types : ';
    foreach ($op_type in $op_filtered_types)
    {
        Write-Verbose ($op_type.Namespace + ', ' + $op_type.Name);
    }

    return $op_filtered_types;
}

# Sample: ServiceName, DeploymentName
function Is-PipingPropertyName
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$parameterName
    )

    if ($parameterName.ToLower() -eq 'servicename')
    {
        return $true;
    }
    elseif ($parameterName.ToLower() -eq 'deploymentname')
    {
        return $true;
    }
    elseif ($parameterName.ToLower() -eq 'rolename')
    {
        return $true;
    }
    elseif ($parameterName.ToLower() -eq 'roleinstancename')
    {
        return $true;
    }
    elseif ($parameterName.ToLower() -eq 'vmimagename')
    {
        return $true;
    }
    elseif ($parameterName.ToLower() -eq 'imagename')
    {
        return $true;
    }
    elseif ($parameterName.ToLower() -eq 'diskname')
    {
        return $true;
    }

    return $false;
}

function Is-PipingPropertyTypeName
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$parameterTypeName
    )
    
    if ($parameterTypeName.ToLower() -eq 'string')
    {
        return $true;
    }
    elseif ($parameterTypeName.ToLower() -eq 'system.string')
    {
        return $true;
    }

    return $false;
}

function Get-VerbTermNameAndSuffix
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$MethodName
    )

    $verb = $MethodName;
    $suffix = $null;

    foreach ($key in $common_verb_mapping.Keys)
    {
        if ($MethodName.StartsWith($key))
        {
            $verb = $common_verb_mapping[$key];
            $suffix = $MethodName.Substring($key.Length);

            if ($MethodName.StartsWith('List'))
            {
                $suffix += 'List';
            }
            elseif ($MethodName.StartsWith('Deallocate'))
            {
                $suffix += "WithDeallocation";
            }

            break;
        }
    }

    Write-Output $verb;
    Write-Output $suffix;
}

function Get-ShortNounName
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$inputNoun
    )

    $noun = $inputNoun;

    foreach ($key in $common_noun_mapping.Keys)
    {
        if ($noun -like ("*${key}*"))
        {
            $noun = $noun.Replace($key, $common_noun_mapping[$key]);
        }
    }

    Write-Output $noun;
}

function Write-PSArgumentFile
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$file_full_path
    )

    $model_source_code_text =
@"
${code_common_header}

$code_using_strs

namespace ${code_model_namespace}
{
    public class PSArgument
    {
        public string Name { get; set; }

        public Type Type { get; set; }

        public object Value { get; set; }
    }
}
"@;

    $st = Set-Content -Path $file_full_path -Value $model_source_code_text -Force;
}

function Write-BaseCmdletFile
{
    # e.g.
    # public abstract class ComputeAutomationBaseCmdlet : Microsoft.WindowsAzure.Commands.Utilities.Common.ServiceManagementBaseCmdlet
    param(
        [Parameter(Mandatory = $True)]
        [string]$file_full_path,

        [Parameter(Mandatory = $True)]
        $operation_name_list,

        [Parameter(Mandatory = $True)]
        $client_class_info
    )

    [System.Reflection.PropertyInfo[]]$propItems = $client_class_info.GetProperties();

    $operation_get_code = "";
    foreach ($opFullName in $operation_name_list)
    {
        [string]$sOpFullName = $opFullName;
        # Write-Verbose ('$sOpFullName = ' + $sOpFullName);
        $prefix = 'I';
        $suffix = 'Operations';
        if ($sOpFullName.StartsWith($prefix) -and $sOpFullName.EndsWith($suffix))
        {
            $opShortName = Get-OperationShortName $sOpFullName;
            $opPropName = $opShortName;
            foreach ($propItem in $propItems)
            {
                if ($propItem.PropertyType.Name -eq $opFullName)
                {
                    $opPropName = $propItem.Name;
                    break;
                }
            }

            $operation_get_template = 
@"
        public I${opShortName}Operations ${opShortName}Client
        {
            get
            {
                return ${base_class_client_field}.${opPropName};
            }
        }
"@;

            if (-not ($operation_get_code -eq ""))
            {
                $operation_get_code += ($new_line_str * 2);
            }

            $operation_get_code += $operation_get_template;
        }
    }

    $cmdlet_source_code_text =
@"
${code_common_header}

$code_using_strs

namespace ${code_common_namespace}
{
    public abstract class ComputeAutomationBaseCmdlet : $baseCmdletFullName
    {
        protected static PSArgument[] ConvertFromObjectsToArguments(string[] names, object[] objects)
        {
            var arguments = new PSArgument[objects.Length];
            
            for (int index = 0; index < objects.Length; index++)
            {
                arguments[index] = new PSArgument
                {
                    Name = names[index],
                    Type = objects[index].GetType(),
                    Value = objects[index]
                };
            }

            return arguments;
        }

        protected static object[] ConvertFromArgumentsToObjects(object[] arguments)
        {
            var objects = new object[arguments.Length];
            
            for (int index = 0; index < arguments.Length; index++)
            {
                if (arguments[index] is PSArgument)
                {
                    objects[index] = ((PSArgument)arguments[index]).Value;
                }
                else
                {
                    objects[index] = arguments[index];
                }
            }

            return objects;
        }

${operation_get_code}
    }
}
"@;

    $st = Set-Content -Path $file_full_path -Value $cmdlet_source_code_text -Force;
}

# Write Invoke Compute Client Cmdlet
function Write-InvokeCmdletFile
{
    # e.g.
    # public partial class InvokeAzureComputeMethodCmdlet : ComputeAutomationBaseCmdlet, IDynamicParameters

    param(
        [Parameter(Mandatory = $True)]
        [string]$file_full_path,

        [Parameter(Mandatory = $True)]
        [string]$invoke_cmdlet_name,

        [Parameter(Mandatory = $True)]
        [string]$base_cmdlet_name,

        [Parameter(Mandatory = $True)]
        $client_class_info,

        [Parameter(Mandatory = $True)]
        $operation_type_list,

        [Parameter(Mandatory = $True)]
        $invoke_cmdlet_method_code,

        [Parameter(Mandatory = $True)]
        $dynamic_param_method_code
    )

    $indents = " " * 8;
    $get_set_block = '{ get; set; }';

    $cmdlet_verb = "Invoke";
    $cmdlet_verb_code = $verbs_lifecycle_invoke;

    $cmdlet_file_name_suffix = 'Cmdlet'
    $cmdlet_class_name = $cmdlet_verb + $invoke_cmdlet_name.Replace($cmdlet_verb, '');
    $cmdlet_noun = $invoke_cmdlet_name.Replace($cmdlet_verb, '').Replace($cmdlet_file_name_suffix, '');

    $normalized_output_type_name = 'object';
    $all_method_names = @();

    foreach ($operation_type in $operation_type_list)
    {
        $op_short_name = Get-OperationShortName $operation_type.Name;
        $operation_method_info_list = $operation_type.GetMethods();

        foreach ($method in $operation_method_info_list)
        {
            if ($method.Name -like 'Begin*')
            {
                continue;
            }

            $invoke_param_set_name = $op_short_name + $method.Name.Replace('Async', '');
            $all_method_names += $invoke_param_set_name;
        }
    }

    $all_method_names_with_quotes = $all_method_names | foreach { "`"" + $_ + "`"" };
    $all_method_names_str = [string]::Join(',' + $new_line_str + (' ' * 12), $all_method_names_with_quotes);
    $validate_all_method_names_code =
@"
        [ValidateSet(
            $all_method_names_str
        )]
"@;

    $dynamic_param_set_name = "InvokeByDynamicParameters";
    $static_param_set_name = "InvokeByStaticParameters";
    $param_set_code +=
@"
        [Parameter(Mandatory = true, ParameterSetName = `"$dynamic_param_set_name`", Position = 0)]
        [Parameter(Mandatory = true, ParameterSetName = `"$static_param_set_name`", Position = 0)]
$validate_all_method_names_code
        public virtual string MethodName $get_set_block

"@;

    $dynamic_parameters_code = "";
    $operations_code = "";
    foreach ($method_name in $all_method_names)
    {
        $operation_code_template =
@"
                    case `"${method_name}`" :
                        Execute${method_name}Method(argumentList);
                        break;
"@;
        $operations_code += $operation_code_template + $new_line_str;

        
        $dynamic_param_code_template =
@"
                    case `"${method_name}`" : return Create${method_name}DynamicParameters();
"@;
        $dynamic_parameters_code += $dynamic_param_code_template + $new_line_str;
    }

    $execute_client_action_code =
@"
        protected object ParseParameter(object input)
        {
            if (input is PSObject)
            {
                return (input as PSObject).BaseObject;
            }
            else
            {
                return input;
            }
        }

        protected override void ProcessRecord()
        {
            base.ProcessRecord();
            ExecuteClientAction(() =>
            {
                if (ParameterSetName == `"$dynamic_param_set_name`")
                {
                    argumentList = ConvertDynamicParameters(dynamicParameters);
                }
                else
                {
                    argumentList = ConvertFromArgumentsToObjects((object[])dynamicParameters[`"ArgumentList`"].Value);
                }

                switch (MethodName)
                {
${operations_code}                    default : WriteWarning(`"Cannot find the method by name = `'`" + MethodName + `"`'.`"); break;
                }
            });
        }
"@;

    # $invoke_cmdlet_method_code_content = ([string]::Join($new_line_str, $invoke_cmdlet_method_code));
    # $dynamic_param_method_code_content = ([string]::Join($new_line_str, $dynamic_param_method_code));

    $cmdlet_source_code_text =
@"
${code_common_header}

$code_using_strs

namespace ${code_common_namespace}
{
    [Cmdlet(${cmdlet_verb_code}, `"${cmdlet_noun}`", DefaultParameterSetName = `"$dynamic_param_set_name`")]
    [OutputType(typeof(${normalized_output_type_name}))]
    public partial class $cmdlet_class_name : $base_cmdlet_name, IDynamicParameters
    {
        protected RuntimeDefinedParameterDictionary dynamicParameters;
        protected object[] argumentList;

        protected static object[] ConvertDynamicParameters(RuntimeDefinedParameterDictionary parameters)
        {
            List<object> paramList = new List<object>();

            foreach (var param in parameters)
            {
                paramList.Add(param.Value.Value);
            }

            return paramList.ToArray();
        }

${param_set_code}
${execute_client_action_code}
$invoke_cmdlet_method_code_content

        public virtual object GetDynamicParameters()
        {
            switch (MethodName)
            {
${dynamic_parameters_code}                    default : break;
            }

            return null;
        }
$dynamic_param_method_code_content
    }
}
"@;

    $st = Set-Content -Path $file_full_path -Value $cmdlet_source_code_text -Force;
}

function Get-ParameterTypeShortName
{
    param(
        [Parameter(Mandatory = $True)]
        $parameter_type_info,

        [Parameter(Mandatory = $false)]
        $is_list_type = $false
    )
    
    if (-not $is_list_type)
    {
        $param_type_full_name = $parameter_type_info.FullName;
        $param_type_full_name = $param_type_full_name.Replace('+', '.');

        $param_type_short_name = $parameter_type_info.Name;
        $param_type_short_name = $param_type_short_name.Replace('+', '.');
    }
    else
    {
        $itemType = $parameter_type_info.GetGenericArguments()[0];
        $itemTypeShortName = $itemType.Name;
        $itemTypeFullName = $itemType.FullName;
        $itemTypeNormalizedShortName = Get-NormalizedTypeName $itemTypeFullName;

        $param_type_full_name = "System.Collections.Generic.List<${itemTypeNormalizedShortName}>";
        $param_type_full_name = $param_type_full_name.Replace('+', '.');

        $param_type_short_name = "${itemTypeShortName}List";
        $param_type_short_name = $param_type_short_name.Replace('+', '.');
    }

    return $param_type_short_name;
}

function Get-ParameterTypeFullName
{
    param(
        [Parameter(Mandatory = $True)]
        $parameter_type_info,

        [Parameter(Mandatory = $false)]
        $is_list_type = $false
    )
    
    if (-not $is_list_type)
    {
        $param_type_full_name = $parameter_type_info.FullName;
        $param_type_full_name = $param_type_full_name.Replace('+', '.');
    }
    else
    {
        $itemType = $parameter_type_info.GetGenericArguments()[0];
        $itemTypeShortName = $itemType.Name;
        $itemTypeFullName = $itemType.FullName;
        $itemTypeNormalizedShortName = Get-NormalizedTypeName $itemTypeFullName;

        $param_type_full_name = "System.Collections.Generic.List<${itemTypeNormalizedShortName}>";
        $param_type_full_name = $param_type_full_name.Replace('+', '.');
    }

    return $param_type_full_name;
}

# Write New Invoke Parameters Cmdlet
function Write-InvokeParameterCmdletFile
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$file_full_path,

        [Parameter(Mandatory = $True)]
        [string]$parameter_cmdlet_name,

        [Parameter(Mandatory = $True)]
        [string]$base_cmdlet_name,

        [Parameter(Mandatory = $True)]
        $client_class_info,

        [Parameter(Mandatory = $True)]
        $operation_type_list,

        [Parameter(Mandatory = $True)]
        $parameter_cmdlet_method_code
    )

    $indents = " " * 8;
    $get_set_block = '{ get; set; }';

    $cmdlet_verb = "New";
    $cmdlet_verb_code = $verbs_common_new;

    $cmdlet_file_name_suffix = 'Cmdlet'
    $cmdlet_class_name = $cmdlet_verb + $parameter_cmdlet_name.Replace($cmdlet_verb, '');
    $cmdlet_noun = $parameter_cmdlet_name.Replace($cmdlet_verb, '').Replace($cmdlet_file_name_suffix, '');

    $normalized_output_type_name = 'object';
    $all_method_names = @();
    $all_param_type_names = @();
    $constructor_code_hashmap = @{};

    foreach ($operation_type in $operation_type_list)
    {
        $op_short_name = Get-OperationShortName $operation_type.Name;
        $operation_method_info_list = $operation_type.GetMethods();
        $parameter_type_info_list = @();

        foreach ($method in $operation_method_info_list)
        {
            if ($method.Name -like 'Begin*')
            {
                continue;
            }

            $invoke_param_set_name = $op_short_name + $method.Name.Replace('Async', '');
            $all_method_names += $invoke_param_set_name;

            [System.Reflection.ParameterInfo]$parameter_type_info = (Get-MethodComplexParameter $method $client_library_namespace);

            if (($parameter_type_info -ne $null) -and (($parameter_type_info_list | where { $_.ParameterType.FullName -eq $parameter_type_info.FullName }).Count -eq 0))
            {
                $parameter_type_info_list += $parameter_type_info;

                $parameter_type_short_name = Get-ParameterTypeShortName $parameter_type_info.ParameterType;
                if (($parameter_type_short_name -like "${op_short_name}*") -and ($parameter_type_short_name.Length -gt $op_short_name.Length))
                {
                    # Remove the common part between the parameter type name and operation short name, e.g. 'VirtualMachineDisk'
                    $parameter_type_short_name = $parameter_type_short_name.Substring($op_short_name.Length);
                }
                $parameter_type_short_name = $op_short_name + $parameter_type_short_name;

                $parameter_type_full_name = Get-ParameterTypeFullName $parameter_type_info.ParameterType;
                if (-not($all_param_type_names -contains $parameter_type_short_name))
                {
                    $all_param_type_names += $parameter_type_short_name;
                    if (-not $constructor_code_hashmap.ContainsKey($parameter_type_short_name))
                    {
                        $st = $constructor_code_hashmap.Add($parameter_type_short_name, (Get-ConstructorCodeByNormalizedTypeName $parameter_type_full_name));
                    }
                }
            }
        }
    }

    $all_method_names_with_quotes = $all_method_names | foreach { "`"" + $_ + "`"" };
    $all_method_names_str = [string]::Join(',' + $new_line_str + (' ' * 12), $all_method_names_with_quotes);
    $validate_all_method_names_code =
@"
        [ValidateSet(
            $all_method_names_str
        )]
"@;

    $param_set_of_create_by_method_name = "CreateParameterListByMethodName";

    $param_set_code +=
@"
        [Parameter(ParameterSetName = `"$param_set_of_create_by_method_name`", Mandatory = true, Position = 0)]
$validate_all_method_names_code
        public virtual string MethodName $get_set_block

"@;


    $operations_code = "";
    foreach ($method_name in $all_method_names)
    {

        $operation_code_template =
@"
                        case `"${method_name}`" : WriteObject(Create${method_name}Parameters(), true); break;
"@;
        $operations_code += $operation_code_template + $new_line_str;
    }

    $execute_client_action_code =
@"
        protected override void ProcessRecord()
        {
            base.ProcessRecord();
            ExecuteClientAction(() =>
            {
                if (ParameterSetName == `"CreateParameterListByMethodName`")
                {
                    switch (MethodName)
                    {
${operations_code}                        default : WriteWarning(`"Cannot find the method by name = `'`" + MethodName + `"`'.`"); break;
                    }
                }
            });
        }
"@;

    # $parameter_cmdlet_method_code_content = ([string]::Join($new_line_str, $parameter_cmdlet_method_code));

    $cmdlet_source_code_text =
@"
${code_common_header}

$code_using_strs

namespace ${code_common_namespace}
{
    [Cmdlet(${cmdlet_verb_code}, `"${cmdlet_noun}`", DefaultParameterSetName = `"$param_set_of_create_by_method_name`")]
    [OutputType(typeof(${normalized_output_type_name}))]
    public partial class $cmdlet_class_name : $base_cmdlet_name
    {
${param_set_code}
${execute_client_action_code}
$parameter_cmdlet_method_code_content
    }
}
"@;

    $st = Set-Content -Path $file_full_path -Value $cmdlet_source_code_text -Force;
}


# Write New Parameter Object Cmdlet
function Write-NewParameterObjectCmdletFile
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$file_full_path,

        [Parameter(Mandatory = $True)]
        [string]$new_object_cmdlet_class_name,

        [Parameter(Mandatory = $True)]
        [string]$base_cmdlet_name,

        [Parameter(Mandatory = $True)]
        $client_class_info,

        [Parameter(Mandatory = $True)]
        $operation_type_list,

        [Parameter(Mandatory = $True)]
        $parameter_cmdlet_method_code
    )

    $indents = " " * 8;
    $get_set_block = '{ get; set; }';

    $cmdlet_verb = "New";
    $cmdlet_verb_code = $verbs_common_new;

    $cmdlet_file_name_suffix = 'Cmdlet'
    $cmdlet_class_name = $cmdlet_verb + $new_object_cmdlet_class_name.Replace($cmdlet_verb, '');
    $cmdlet_noun = $new_object_cmdlet_class_name.Replace($cmdlet_verb, '').Replace($cmdlet_file_name_suffix, '');

    $normalized_output_type_name = 'object';
    $all_method_names = @();
    $all_param_type_names = @();
    $constructor_code_hashmap = @{};
    $all_param_full_type_names = @();

    foreach ($operation_type in $operation_type_list)
    {
        $op_short_name = Get-OperationShortName $operation_type.Name;
        $operation_method_info_list = $operation_type.GetMethods();
        $parameter_type_info_list = @();

        foreach ($method in $operation_method_info_list)
        {
            if ($method.Name -like 'Begin*')
            {
                continue;
            }

            $invoke_param_set_name = $op_short_name + $method.Name.Replace('Async', '');
            $all_method_names += $invoke_param_set_name;

            [System.Reflection.ParameterInfo]$parameter_type_info = (Get-MethodComplexParameter $method $client_library_namespace);

            if (($parameter_type_info -ne $null) -and (($parameter_type_info_list | where { $_.ParameterType.FullName -eq $parameter_type_info.FullName }).Count -eq 0))
            {
                $parameter_type_info_list += $parameter_type_info;

                $parameter_type_short_name = Get-ParameterTypeShortName $parameter_type_info.ParameterType;
                if (($parameter_type_short_name -like "${op_short_name}*") -and ($parameter_type_short_name.Length -gt $op_short_name.Length))
                {
                    # Remove the common part between the parameter type name and operation short name, e.g. 'VirtualMachineDisk'
                    $parameter_type_short_name = $parameter_type_short_name.Substring($op_short_name.Length);
                }
                $parameter_type_short_name = $op_short_name + $parameter_type_short_name;

                $parameter_type_full_name = Get-ParameterTypeFullName $parameter_type_info.ParameterType;
                if (-not($all_param_type_names -contains $parameter_type_short_name))
                {
                    $all_param_type_names += $parameter_type_short_name;
                    if (-not $constructor_code_hashmap.ContainsKey($parameter_type_short_name))
                    {
                        $st = $constructor_code_hashmap.Add($parameter_type_short_name, (Get-ConstructorCodeByNormalizedTypeName $parameter_type_full_name));
                    }
                }

                if (-not($all_param_full_type_names -contains $parameter_type_full_name))
                {
                    $all_param_full_type_names += $parameter_type_full_name;
                    if (-not $constructor_code_hashmap.ContainsKey($parameter_type_full_name))
                    {
                        $st = $constructor_code_hashmap.Add($parameter_type_full_name, (Get-ConstructorCodeByNormalizedTypeName $parameter_type_full_name));
                    }
                }

                # Run Through the Sub Parameter List
                $subParamTypeList = Get-SubComplexParameterList $parameter_type_info $client_library_namespace;

                if ($subParamTypeList.Count -gt 0)
                {
                    foreach ($sp in $subParamTypeList)
                    {
                        if (-not $sp.IsGenericType)
                        {
                            $parameter_type_short_name = Get-ParameterTypeShortName $sp;
                            if (($parameter_type_short_name -like "${op_short_name}*") -and ($parameter_type_short_name.Length -gt $op_short_name.Length))
                            {
                                # Remove the common part between the parameter type name and operation short name, e.g. 'VirtualMachineDisk'
                                $parameter_type_short_name = $parameter_type_short_name.Substring($op_short_name.Length);
                            }
                            $parameter_type_short_name = $op_short_name + $parameter_type_short_name;

                            $parameter_type_full_name = Get-ParameterTypeFullName $sp;
                            if (-not $constructor_code_hashmap.ContainsKey($parameter_type_short_name))
                            {
                                $st = $constructor_code_hashmap.Add($parameter_type_short_name, (Get-ConstructorCodeByNormalizedTypeName $parameter_type_full_name));
                            }

                            if (-not $constructor_code_hashmap.ContainsKey($parameter_type_full_name))
                            {
                                $st = $constructor_code_hashmap.Add($parameter_type_full_name, (Get-ConstructorCodeByNormalizedTypeName $parameter_type_full_name));
                            }
                        }
                        else
                        {
                            $parameter_type_short_name = Get-ParameterTypeShortName $sp $true;
                            if (($parameter_type_short_name -like "${op_short_name}*") -and ($parameter_type_short_name.Length -gt $op_short_name.Length))
                            {
                                # Remove the common part between the parameter type name and operation short name, e.g. 'VirtualMachineDisk'
                                $parameter_type_short_name = $parameter_type_short_name.Substring($op_short_name.Length);
                            }
                            $parameter_type_short_name = $op_short_name + $parameter_type_short_name;

                            $parameter_type_full_name = Get-ParameterTypeFullName $sp $true;
                            if (-not $constructor_code_hashmap.ContainsKey($parameter_type_short_name))
                            {
                                $st = $constructor_code_hashmap.Add($parameter_type_short_name, (Get-ConstructorCodeByNormalizedTypeName $parameter_type_full_name));
                            }

                            if (-not $constructor_code_hashmap.ContainsKey($parameter_type_full_name))
                            {
                                $st = $constructor_code_hashmap.Add($parameter_type_full_name, (Get-ConstructorCodeByNormalizedTypeName $parameter_type_full_name));
                            }
                        }

                        if (-not($all_param_type_names -contains $parameter_type_short_name))
                        {
                            $all_param_type_names += $parameter_type_short_name;
                        }
                        
                        if (-not($all_param_full_type_names -contains $parameter_type_full_name))
                        {
                            $all_param_full_type_names += $parameter_type_full_name;
                        }
                    }
                }
            }
        }
    }

    $all_param_type_names = $all_param_type_names | Sort;
    $all_param_type_names_with_quotes = $all_param_type_names | foreach { "`"" + $_ + "`"" };
    $all_param_names_str = [string]::Join(',' + $new_line_str + (' ' * 12), $all_param_type_names_with_quotes);
    $validate_all_param_names_code =
@"
        [ValidateSet(
            $all_param_names_str
        )]
"@;

    $all_param_full_type_names = $all_param_full_type_names | Sort;
    $all_param_full_type_names_with_quotes = $all_param_full_type_names | foreach { "`"" + $_ + "`"" };
    $all_param_full_names_str = [string]::Join(',' + $new_line_str + (' ' * 12), $all_param_full_type_names_with_quotes);
    $validate_all_param_full_names_code =
@"
        [ValidateSet(
            $all_param_full_names_str
        )]
"@;

    $param_set_of_create_by_type_name = "CreateParameterObjectByFriendlyName";
    $param_set_of_create_by_full_type_name = "CreateParameterObjectByFullName";

    $param_set_code +=
@"
        [Parameter(ParameterSetName = `"$param_set_of_create_by_type_name`", Mandatory = true, Position = 0)]
$validate_all_param_names_code
        public string FriendlyName $get_set_block

        [Parameter(ParameterSetName = `"$param_set_of_create_by_full_type_name`", Mandatory = true, Position = 0)]
$validate_all_param_full_names_code
        public string FullName $get_set_block

"@;


    $operations_code = "";
    foreach ($method_name in $all_method_names)
    {

        $operation_code_template =
@"
                        case `"${method_name}`" : WriteObject(Create${method_name}Parameters()); break;
"@;
        $operations_code += $operation_code_template + $new_line_str;
    }

    $type_operations_code = "";
    foreach ($type_name in $all_param_type_names)
    {
        $constructor_code = $constructor_code_hashmap.Get_Item($type_name);
        $type_code_template =
@"
                        case `"${type_name}`" : WriteObject(${constructor_code}); break;
"@;
        $type_operations_code += $type_code_template + $new_line_str;
    }

    $full_type_operations_code = "";
    foreach ($type_name in $all_param_full_type_names)
    {
        $constructor_code = $constructor_code_hashmap.Get_Item($type_name);
        $full_type_code_template =
@"
                        case `"${type_name}`" : WriteObject(${constructor_code}); break;
"@;
        $full_type_operations_code += $full_type_code_template + $new_line_str;
    }

    $execute_client_action_code =
@"
        protected override void ProcessRecord()
        {
            base.ProcessRecord();
            ExecuteClientAction(() =>
            {
                if (ParameterSetName == `"$param_set_of_create_by_type_name`")
                {
                    switch (FriendlyName)
                    {
${type_operations_code}                        default : WriteWarning(`"Cannot find the type by FriendlyName = `'`" + FriendlyName + `"`'.`"); break;
                    }
                }
                else if (ParameterSetName == `"$param_set_of_create_by_full_type_name`")
                {
                    switch (FullName)
                    {
${full_type_operations_code}                        default : WriteWarning(`"Cannot find the type by FullName = `'`" + FullName + `"`'.`"); break;
                    }
                }
            });
        }
"@;

    # $parameter_cmdlet_method_code_content = ([string]::Join($new_line_str, $parameter_cmdlet_method_code));

    $cmdlet_source_code_text =
@"
${code_common_header}

$code_using_strs

namespace ${code_common_namespace}
{
    [Cmdlet(${cmdlet_verb_code}, `"${cmdlet_noun}`", DefaultParameterSetName = `"$param_set_of_create_by_full_type_name`")]
    [OutputType(typeof(${normalized_output_type_name}))]
    public partial class $new_object_cmdlet_class_name : $base_cmdlet_name
    {
${param_set_code}
${execute_client_action_code}
$parameter_cmdlet_method_code_content
    }
}
"@;

    $st = Set-Content -Path $file_full_path -Value $cmdlet_source_code_text -Force;
}

# Sample: VirtualMachineGetMethod.cs
function Write-OperationCmdletFile
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$fileOutputFolder,

        [Parameter(Mandatory = $True)]
        $opShortName,

        [Parameter(Mandatory = $True)]
        [System.Reflection.MethodInfo]$operation_method_info,

        [Parameter(Mandatory = $True)]
        [string]$invoke_cmdlet_class_name,

        [Parameter(Mandatory = $True)]
        [string]$parameter_cmdlet_class_name
    )

    $methodName = ($operation_method_info.Name.Replace('Async', ''));
    $return_type_info = $operation_method_info.ReturnType.GenericTypeArguments[0];
    $normalized_output_type_name = Get-NormalizedTypeName $return_type_info.Name;
    $cmdlet_verb = "Invoke";
    $cmdlet_verb_code = $verbs_lifecycle_invoke;
    $cmdlet_noun_prefix = 'Azure';
    $cmdlet_noun_suffix = 'Method';
    $cmdlet_noun = $cmdlet_noun_prefix + $opShortName + $methodName + $cmdlet_noun_suffix;
    $cmdlet_class_name = $cmdlet_verb + $cmdlet_noun;

    $invoke_param_set_name = $opShortName + $methodName;

    $file_full_path = $fileOutputFolder + '/' + $cmdlet_class_name + '.cs';
    if (Test-Path $file_full_path)
    {
        return;
    }

    $indents = " " * 8;
    $get_set_block = '{ get; set; }';
    $invoke_input_params_name = 'invokeMethodInputParameters';
    
    $cmdlet_generated_code = '';
    # $cmdlet_generated_code += $indents + '// ' + $operation_method_info + $new_line_str;

    $params = $operation_method_info.GetParameters();
    [System.Collections.ArrayList]$param_names = @();
    [System.Collections.ArrayList]$invoke_param_names = @();
    [System.Collections.ArrayList]$invoke_local_param_names = @();
    [System.Collections.ArrayList]$create_local_param_names = @();
    [System.Collections.ArrayList]$cli_command_param_names = @();
    $position_index = 1;
    foreach ($pt in $params)
    {
        $paramTypeFullName = $pt.ParameterType.FullName;
        if (-not ($paramTypeFullName.EndsWith('CancellationToken')))
        {
            $normalized_param_name = Get-NormalizedName $pt.Name;

            Write-Output ('    ' + $paramTypeFullName + ' ' + $normalized_param_name);

            $paramTypeNormalizedName = Get-NormalizedTypeName -inputName $paramTypeFullName;
            $param_constructor_code = Get-ConstructorCodeByNormalizedTypeName -inputName $paramTypeNormalizedName;

            $param_attributes = $indents + "[Parameter(Mandatory = true";
            $invoke_param_attributes = $indents + "[Parameter(ParameterSetName = `"${invoke_param_set_name}`", Position = ${position_index}, Mandatory = true";
            if ((Is-PipingPropertyName $normalized_param_name) -and (Is-PipingPropertyTypeName $paramTypeNormalizedName))
            {
                $piping_from_property_name_code = ", ValueFromPipelineByPropertyName = true";
                $param_attributes += $piping_from_property_name_code;

                $invoke_param_attributes += $piping_from_property_name_code;
            }
            $param_attributes += ")]" + $new_line_str;
            $invoke_param_attributes += ")]" + $new_line_str;
            $param_definition = $indents + "public ${paramTypeNormalizedName} ${normalized_param_name} " + $get_set_block + $new_line_str;
            $invoke_param_definition = $indents + "public ${paramTypeNormalizedName} ${invoke_param_set_name}${normalized_param_name} " + $get_set_block + $new_line_str;
            $param_index = $position_index - 1;
            $invoke_local_param_definition = $indents + (' ' * 4) + "${paramTypeNormalizedName} " + $pt.Name + " = (${paramTypeNormalizedName})ParseParameter(${invoke_input_params_name}[${param_index}]);";
            $create_local_param_definition = $indents + (' ' * 4) + "${paramTypeNormalizedName} " + $pt.Name + " = ${param_constructor_code};";
            $param_code_content = $param_attributes + $param_definition;

            # For Invoke Method
            $invoke_param_definition = $indents + "public ${paramTypeNormalizedName} ${invoke_param_set_name}${normalized_param_name} " + $get_set_block + $new_line_str;
            $invoke_param_code_content += $invoke_param_attributes + $invoke_param_definition + $new_line_str;
            $invoke_local_param_code_content += $invoke_local_param_definition + $new_line_str;
            $create_local_param_code_content += $create_local_param_definition + $new_line_str;

            $cmdlet_generated_code += $param_code_content + $new_line_str;

            $st = $param_names.Add($normalized_param_name);
            $st = $invoke_param_names.Add((${invoke_param_set_name} + $normalized_param_name));
            $st = $invoke_local_param_names.Add($pt.Name);

            $position_index += 1;
        }
    }

    $params_join_str = [string]::Join(', ', $param_names.ToArray());
    $invoke_params_join_str = [string]::Join(', ', $invoke_param_names.ToArray());
    $invoke_local_params_join_str = [string]::Join(', ', $invoke_local_param_names.ToArray());

    $invoke_local_param_names_join_str = "`"" + [string]::Join('", "', $param_names.ToArray()) + "`"";

    $cmdlet_client_call_template =
@"
        protected override void ProcessRecord()
        {
            base.ProcessRecord();
            ExecuteClientAction(() =>
            {
                var result = ${opShortName}Client.${methodName}(${params_join_str});
                WriteObject(result);
            });
        }
"@;

    $cmdlet_generated_code += $cmdlet_client_call_template;

    $dynamic_param_assignment_code_lines = @();
    $param_index = 1;
    foreach ($pt in $params)
    {
        $param_type_full_name = $pt.ParameterType.FullName;
        if ($param_type_full_name.EndsWith('CancellationToken'))
        {
            continue;
        }

        $param_name = Get-NormalizedName $pt.Name;
        $expose_param_name = $param_name;
        if ($expose_param_name -like '*Parameters')
        {
            $expose_param_name = $invoke_param_set_name + $expose_param_name;
        }

        $dynamic_param_assignment_code_lines +=
@"
            var p${param_name} = new RuntimeDefinedParameter();
            p${param_name}.Name = `"${expose_param_name}`";
            p${param_name}.ParameterType = typeof($param_type_full_name);
            p${param_name}.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByDynamicParameters",
                Position = $param_index,
                Mandatory = true
            });
            p${param_name}.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add(`"${expose_param_name}`", p${param_name});

"@;
        $param_index += 1;
    }

    $param_name = $expose_param_name = 'ArgumentList';
    $param_type_full_name = 'object[]';
    $dynamic_param_assignment_code_lines +=
@"
            var p${param_name} = new RuntimeDefinedParameter();
            p${param_name}.Name = `"${expose_param_name}`";
            p${param_name}.ParameterType = typeof($param_type_full_name);
            p${param_name}.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByStaticParameters",
                Position = $param_index,
                Mandatory = true
            });
            p${param_name}.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add(`"${expose_param_name}`", p${param_name});

"@;

    $dynamic_param_assignment_code = [string]::Join($new_line_str, $dynamic_param_assignment_code_lines);

    $dynamic_param_source_template =
@"
        protected object Create${invoke_param_set_name}DynamicParameters()
        {
            dynamicParameters = new RuntimeDefinedParameterDictionary();
$dynamic_param_assignment_code
            return dynamicParameters;
        }
"@;

    $invoke_cmdlt_source_template =
@"
        protected void Execute${invoke_param_set_name}Method(object[] ${invoke_input_params_name})
        {
${invoke_local_param_code_content}
            var result = ${opShortName}Client.${methodName}(${invoke_local_params_join_str});
            WriteObject(result);
        }
"@;

    $parameter_cmdlt_source_template =
@"
        protected PSArgument[] Create${invoke_param_set_name}Parameters()
        {
${create_local_param_code_content}
            return ConvertFromObjectsToArguments(new string[] { $invoke_local_param_names_join_str }, new object[] { ${invoke_local_params_join_str} });
        }
"@;

    # 1. Invoke Cmdlet Partial Code
    # 2. Param Cmdlet Partial Code
    # 3. Verb Cmdlet Partial Code
    $return_vals = Get-VerbTermNameAndSuffix $methodName;
    $mapped_verb_name = $return_vals[0];
    $mapped_verb_term_suffix = $return_vals[1];
    $shortNounName = Get-ShortNounName $opShortName;

    $mapped_noun_str = 'Azure' + $shortNounName + $mapped_verb_term_suffix;
    $verb_cmdlet_name = $mapped_verb_name + $mapped_noun_str;

    # Construct the Individual Cmdlet Code Content
    $cmdlet_partial_class_code =
@"
    public partial class ${invoke_cmdlet_class_name} : ComputeAutomationBaseCmdlet
    {
$dynamic_param_source_template

$invoke_cmdlt_source_template
    }

    public partial class ${parameter_cmdlet_class_name} : ComputeAutomationBaseCmdlet
    {
$parameter_cmdlt_source_template
    }
"@;

    if ($cmdletFlavor -eq 'Verb')
    {
        # If the Cmdlet Flavor is 'Verb', generate the Verb-based cmdlet code
        $cmdlet_partial_class_code +=
@"


    [Cmdlet(`"${mapped_verb_name}`", `"${mapped_noun_str}`")]
    public partial class $verb_cmdlet_name : ${invoke_cmdlet_class_name}
    {
        public $verb_cmdlet_name()
        {
            this.MethodName = `"$invoke_param_set_name`";
        }

        public override string MethodName { get; set; }

        protected override void ProcessRecord()
        {
            base.ProcessRecord();
        }

        public override object GetDynamicParameters()
        {
            dynamicParameters = new RuntimeDefinedParameterDictionary();
$dynamic_param_assignment_code
            return dynamicParameters;
        }
    }
"@;
    }

    $cmdlt_source_template =
@"
${code_common_header}

$code_using_strs

namespace ${code_common_namespace}
{
    [Cmdlet(${cmdlet_verb_code}, `"${cmdlet_noun}`")]
    [OutputType(typeof(${normalized_output_type_name}))]
    public class ${cmdlet_class_name} : ComputeAutomationBaseCmdlet
    {
${cmdlet_generated_code}
    }

${cmdlet_partial_class_code}
}
"@;

    $cmdlt_partial_class_source_template =
@"
${code_common_header}

$code_using_strs

namespace ${code_common_namespace}
{
${cmdlet_partial_class_code}
}
"@;

    #$st = Set-Content -Path $file_full_path -Value $cmdlt_source_template -Force;
    $partial_class_file_path = ($file_full_path.Replace('InvokeAzure', ''));
    $st = Set-Content -Path $partial_class_file_path -Value $cmdlt_partial_class_source_template -Force;

    Write-Output $dynamic_param_source_template;
    Write-Output $invoke_cmdlt_source_template;
    Write-Output $parameter_cmdlt_source_template;

    # 3. CLI Code
    # 3.1 types
    $function_comment = "";
    foreach ($pt in $params)
    {
        $param_type_full_name = $pt.ParameterType.FullName;
        if (-not ($param_type_full_name.EndsWith('CancellationToken')))
        {
            if ($pt.Name -like '*parameters')
            {
                $param_object = (. $PSScriptRoot\Create-ParameterObject.ps1 -typeInfo $pt.ParameterType);
                $param_object_comment = (. $PSScriptRoot\ConvertTo-Json.ps1 -inputObject $param_object -compress $true);
                $param_object_comment_no_compress = (. $PSScriptRoot\ConvertTo-Json.ps1 -inputObject $param_object);
            }
        }
    }

    # 3.2 functions
    $category_name = Get-CliCategoryName $opShortName;
    $cli_method_name = Get-CliNormalizedName $methodName;
    $cli_method_option_name = Get-CliOptionName $methodName;
    $cli_op_name = Get-CliNormalizedName $opShortName;
    $cli_op_description = (Get-CliOptionName $opShortName).Replace('-', ' ');

    $cli_op_code_content += "//" + $cli_op_name + " -> " + $methodName + $new_line_str;
    if ($param_object_comment -ne $null)
    {
        $cli_op_code_content += "/*" + $new_line_str + $param_object_comment + $new_line_str + "*/" + $new_line_str;
    }

    $cli_op_code_content += "  var $category_name = cli.category('${category_name}').description(`$('Commands to manage your $cli_op_description.'));" + $new_line_str;

    $cli_op_code_content += "  ${category_name}.command('${cli_method_option_name}')" + $new_line_str;
    $cli_op_code_content += "  .description(`$('${cli_method_option_name} method to manage your $cli_op_description.'))" + $new_line_str;
    $cli_op_code_content += "  .usage('[options]')" + $new_line_str;
    for ($index = 0; $index -lt $param_names.Count; $index++)
    {
        $cli_option_name = Get-CliOptionName $param_names[$index];
        $cli_op_code_content += "  .option('--${cli_option_name} <${cli_option_name}>', `$('${cli_option_name}'))" + $new_line_str;
    }
    $cli_op_code_content += "  .option('--parameter-file <parameter-file>', `$('the input parameter file'))" + $new_line_str;
    $cli_op_code_content += "  .option('-s, --subscription <subscription>', `$('the subscription identifier'))" + $new_line_str;
    $cli_op_code_content += "  .execute(function ("
    for ($index = 0; $index -lt $param_names.Count; $index++)
    {
        if ($index -gt 0) { $cli_op_code_content += ", "; }
        $cli_param_name = Get-CliNormalizedName $param_names[$index];
        $cli_op_code_content += "$cli_param_name";
    }
    $cli_op_code_content += ", options, _) {" + $new_line_str;
    for ($index = 0; $index -lt $param_names.Count; $index++)
    {
        $cli_param_name = Get-CliNormalizedName $param_names[$index];
        $cli_op_code_content += "    console.log('${cli_param_name} = ' + options.${cli_param_name});" + $new_line_str;
        if (${cli_param_name} -eq 'Parameters')
        {
            $cli_op_code_content += "    if (options.parameterFile) {" + $new_line_str;
            $cli_op_code_content += "      console.log(`"Reading file content from: \`"`" + options.parameterFile + `"\`"`");" + $new_line_str;
            $cli_op_code_content += "      var fileContent = fs.readFileSync(options.parameterFile, 'utf8');" + $new_line_str;
            $cli_op_code_content += "      var ${cli_param_name}Obj = JSON.parse(fileContent);" + $new_line_str;
            $cli_op_code_content += "    }" + $new_line_str;
            $cli_op_code_content += "    else {" + $new_line_str;
            $cli_op_code_content += "      var ${cli_param_name}Obj = JSON.parse(options.${cli_param_name});" + $new_line_str;
            $cli_op_code_content += "    }" + $new_line_str;
            $cli_op_code_content += "    console.log('${cli_param_name}Obj = ' + JSON.stringify(${cli_param_name}Obj));" + $new_line_str;
        }
    }
    $cli_op_code_content += "    var subscription = profile.current.getSubscription(options.subscription);" + $new_line_str;
    $cli_op_code_content += "    var computeManagementClient = utils.createComputeResourceProviderClient(subscription);" + $new_line_str;
    $cli_op_code_content += "    var result = computeManagementClient.${cli_op_name}s.${cli_method_name}(";
    for ($index = 0; $index -lt $param_names.Count; $index++)
    {
        if ($index -gt 0) { $cli_op_code_content += ", "; }
        
        $cli_param_name = Get-CliNormalizedName $param_names[$index];
        if (${cli_param_name} -eq 'Parameters')
        {
            $cli_op_code_content += "${cli_param_name}Obj";
        }
        else
        {
            $cli_op_code_content += "options.${cli_param_name}";
        }
    }
    $cli_op_code_content += ", _);" + $new_line_str;
    $cli_op_code_content += "    cli.output.json(result);" + $new_line_str;
    $cli_op_code_content += "  });" + $new_line_str;

    # 3.3 Parameters
    for ($index = 0; $index -lt $param_names.Count; $index++)
    {
        $cli_param_name = Get-CliNormalizedName $param_names[$index];
        if ($cli_param_name -eq 'Parameters')
        {
            $params_category_name = 'parameters';
            $params_generate_category_name = 'generate';

            # 3.3.1 Parameter Generate Command
            $cli_op_code_content += "  var ${params_category_name} = ${category_name}.category('${params_category_name}')" + $new_line_str;
            $cli_op_code_content += "  .description(`$('Commands to manage parameter for your ${cli_op_description}.'));" + $new_line_str;
            $cli_op_code_content += "  var ${params_generate_category_name} = ${params_category_name}.category('${params_generate_category_name}')" + $new_line_str;
            $cli_op_code_content += "  .description(`$('Commands to generate parameter file for your ${cli_op_description}.'));" + $new_line_str;
            $cli_op_code_content += "  ${params_generate_category_name}.command('${cli_method_option_name}')" + $new_line_str;
            $cli_op_code_content += "  .description(`$('Generate ${category_name} parameter string or files.'))" + $new_line_str;
            $cli_op_code_content += "  .usage('[options]')" + $new_line_str;
            $cli_op_code_content += "  .option('--parameter-file <parameter-file>', `$('The parameter file path.'))" + $new_line_str;
            $cli_op_code_content += "  .execute(function (";
            $cli_op_code_content += "parameterFile";
            $cli_op_code_content += ", options, _) {" + $new_line_str;

            $output_content = $param_object_comment.Replace("`"", "\`"");
            $cli_op_code_content += "    console.log(`"" + $output_content + "`");" + $new_line_str;

            $file_content = $param_object_comment_no_compress.Replace($new_line_str, "\r\n").Replace("`r", "\r").Replace("`n", "\n");
            $file_content = $file_content.Replace("`"", "\`"").Replace(' ', '');
            $cli_op_code_content += "    var filePath = `"${category_name}_${cli_method_name}.json`";" + $new_line_str;
            $cli_op_code_content += "    if (options.parameterFile) { filePath = options.parameterFile; };" + $new_line_str;
            $cli_op_code_content += "    fs.writeFileSync(filePath, beautify(`"" + $file_content + "`"));" + $new_line_str;
            $cli_op_code_content += "    console.log(`"=====================================`");" + $new_line_str;
            $cli_op_code_content += "    console.log(`"Parameter file output to: `" + filePath);" + $new_line_str;
            $cli_op_code_content += "    console.log(`"=====================================`");" + $new_line_str;
            $cli_op_code_content += "  });" + $new_line_str;
            $cli_op_code_content += $new_line_str;

            # 3.3.2 Parameter Patch Command
            $cli_op_code_content += "  ${params_category_name}.command('patch')" + $new_line_str;
            $cli_op_code_content += "  .description(`$('Command to patch ${category_name} parameter JSON file.'))" + $new_line_str;
            $cli_op_code_content += "  .usage('[options]')" + $new_line_str;
            $cli_op_code_content += "  .option('--parameter-file <parameter-file>', `$('The parameter file path.'))" + $new_line_str;
            $cli_op_code_content += "  .option('--operation <operation>', `$('The JSON patch operation: add, remove, or replace.'))" + $new_line_str;
            $cli_op_code_content += "  .option('--path <path>', `$('The JSON data path, e.g.: \`"foo/1\`".'))" + $new_line_str;
            $cli_op_code_content += "  .option('--value <value>', `$('The JSON value.'))" + $new_line_str;
            $cli_op_code_content += "  .execute(function (parameterFile, operation, path, value, options, _) {" + $new_line_str;
            $cli_op_code_content += "    console.log(options.parameterFile);" + $new_line_str;
            $cli_op_code_content += "    console.log(options.operation);" + $new_line_str;
            $cli_op_code_content += "    console.log(options.path);" + $new_line_str;
            $cli_op_code_content += "    console.log(options.value);" + $new_line_str;
            $cli_op_code_content += "    console.log(`"=====================================`");" + $new_line_str;
            $cli_op_code_content += "    console.log(`"Reading file content from: \`"`" + options.parameterFile + `"\`"`");" + $new_line_str;
            $cli_op_code_content += "    console.log(`"=====================================`");" + $new_line_str;
            $cli_op_code_content += "    var fileContent = fs.readFileSync(options.parameterFile, 'utf8');" + $new_line_str;
            $cli_op_code_content += "    var ${cli_param_name}Obj = JSON.parse(fileContent);" + $new_line_str;
            $cli_op_code_content += "    console.log(`"JSON object:`");" + $new_line_str;
            $cli_op_code_content += "    console.log(JSON.stringify(${cli_param_name}Obj));" + $new_line_str;
            $cli_op_code_content += "    if (options.operation == 'add') {" + $new_line_str;
            $cli_op_code_content += "      jsonpatch.apply(${cli_param_name}Obj, [{op: options.operation, path: options.path, value: JSON.parse(options.value)}]);" + $new_line_str;
            $cli_op_code_content += "    }" + $new_line_str;
            $cli_op_code_content += "    else if (options.operation == 'remove' && jsonpatch.apply(${cli_param_name}Obj, [{op: 'test', path: options.path}])) {" + $new_line_str;
            $cli_op_code_content += "      jsonpatch.apply(${cli_param_name}Obj, [{op: options.operation, path: options.path}]);" + $new_line_str;
            $cli_op_code_content += "    }" + $new_line_str;
            $cli_op_code_content += "    else if (options.operation == 'replace') {" + $new_line_str;
            $cli_op_code_content += "      jsonpatch.apply(${cli_param_name}Obj, [{op: options.operation, path: options.path, value: JSON.parse(options.value)}]);" + $new_line_str;
            $cli_op_code_content += "    }" + $new_line_str;
            $cli_op_code_content += "    var updatedContent = JSON.stringify(${cli_param_name}Obj);" + $new_line_str;
            $cli_op_code_content += "    console.log(`"=====================================`");" + $new_line_str;
            $cli_op_code_content += "    console.log(`"JSON object (updated):`");" + $new_line_str;
            $cli_op_code_content += "    console.log(JSON.stringify(${cli_param_name}Obj));" + $new_line_str;
            $cli_op_code_content += "    console.log(`"=====================================`");" + $new_line_str;
            $cli_op_code_content += "    fs.writeFileSync(options.parameterFile, beautify(updatedContent));" + $new_line_str;
            $cli_op_code_content += "    console.log(`"=====================================`");" + $new_line_str;
            $cli_op_code_content += "    console.log(`"Parameter file updated at: `" + options.parameterFile);" + $new_line_str;
            $cli_op_code_content += "    console.log(`"=====================================`");" + $new_line_str;
            $cli_op_code_content += "  });" + $new_line_str;
            $cli_op_code_content += $new_line_str;
            break;
        }
    }

    Write-Output $cli_op_code_content;
}

# Sample: VirtualMachineCreateParameters
function Is-ClientComplexType
{
    param(
        [Parameter(Mandatory = $True)]
        $type_info
    )

    return ($type_info.Namespace -like "${client_name_space}.Model?") -and (-not $type_info.IsEnum);
}

# Sample: IList<ConfigurationSet>
function Is-ListComplexType
{
    param(
        [Parameter(Mandatory = $True)]
        $type_info
    )

    if ($type_info.IsGenericType)
    {
        $args = $list_item_type = $type_info.GetGenericArguments();

        if ($args.Count -eq 1)
        {
            $list_item_type = $type_info.GetGenericArguments()[0];

            if (Is-ClientComplexType $list_item_type)
            {
                return $true;
            }
        }
    }

    return $false;
}

# Sample: IList<ConfigurationSet> => ConfigurationSet
function Get-ListComplexItemType
{
    param(
        [Parameter(Mandatory = $True)]
        $type_info
    )

    if ($type_info.IsGenericType)
    {
        $args = $list_item_type = $type_info.GetGenericArguments();

        if ($args.Count -eq 1)
        {
            $list_item_type = $type_info.GetGenericArguments()[0];

            if (Is-ClientComplexType $list_item_type)
            {
                return $list_item_type;
            }
        }
    }

    return $null;
}

# Sample: VirtualMachines.Create(...) => VirtualMachineCreateParameters
function Get-MethodComplexParameter
{
    param(
        [Parameter(Mandatory = $True)]
        [System.Reflection.MethodInfo]$op_method_info,

        [Parameter(Mandatory = $True)]
        [string]$client_name_space
    )

    $params = $op_method_info.GetParameters();
    $paramsWithoutEnums = $params | where { -not $_.ParameterType.IsEnum };

    # Assume that each operation method has only one complext parameter type
    $param_info = $paramsWithoutEnums | where { $_.ParameterType.Namespace -like "${client_name_space}.Model?" } | select -First 1;

    return $param_info;
}

# Sample: VirtualMachineCreateParameters => ConfigurationSet, VMImageInput, ...
function Get-SubComplexParameterListFromType
{
    param(
        [Parameter(Mandatory = $True)]
        $type_info,

        [Parameter(Mandatory = $True)]
        [string]$client_name_space
    )

    $subParamTypeList = @();

    if (-not (Is-ClientComplexType $type_info))
    {
        return $subParamTypeList;
    }

    $paramProps = $type_info.GetProperties();
    foreach ($pp in $paramProps)
    {
        $isClientType = $false;
        if (Is-ClientComplexType $pp.PropertyType)
        {
            $subParamTypeList += $pp.PropertyType;
            $isClientType = $true;
        }
        elseif (Is-ListComplexType $pp.PropertyType)
        {
            $subParamTypeList += $pp.PropertyType;
            $subParamTypeList += Get-ListComplexItemType $pp.PropertyType;
            $isClientType = $true;
        }

        if ($isClientType)
        {
            $recursiveSubParamTypeList = Get-SubComplexParameterListFromType $pp.PropertyType $client_name_space;
            foreach ($rsType in $recursiveSubParamTypeList)
            {
                $subParamTypeList += $rsType;
            }
        }
    }

    return $subParamTypeList;
}

# Sample: VirtualMachineCreateParameters => ConfigurationSet, VMImageInput, ...
function Get-SubComplexParameterList
{
    param(
        [Parameter(Mandatory = $True)]
        [System.Reflection.ParameterInfo]$param_info,

        [Parameter(Mandatory = $True)]
        [string]$client_name_space
    )

    return Get-SubComplexParameterListFromType $param_info.ParameterType $client_name_space;
}

# Get proper type name
function Get-ProperTypeName
{
    param([System.Type] $itemType)

    if ($itemType.IsGenericType -and ($itemType.Name.StartsWith('IList') -or $itemType.Name.StartsWith('List')))
    {
        $typeStr = 'IList<' + $itemType.GenericTypeArguments[0].Name + '>';
    }
    elseif ($itemType.IsGenericType -and ($itemType.Name.StartsWith('IDictionary') -or $itemType.Name.StartsWith('Dictionary')))
    {
        $typeStr = 'IDictionary<' + $itemType.GenericTypeArguments[0].Name + ',' + $itemType.GenericTypeArguments[1].Name + '>';
    }
    elseif ($itemType.IsGenericType -and $itemType.Name.StartsWith('Nullable'))
    {
        $typeStr = $itemType.GenericTypeArguments[0].Name + '?';
    }
    else
    {
        $typeStr = $itemType.Name;
    }

    $typeStr = $typeStr.Replace("System.String", "string");
    $typeStr = $typeStr.Replace("String", "string");
    $typeStr = $typeStr.Replace("System.Boolean", "bool");
    $typeStr = $typeStr.Replace("Boolean", "bool");
    $typeStr = $typeStr.Replace("System.UInt32", "uint");
    $typeStr = $typeStr.Replace("UInt32", "uint");
    $typeStr = $typeStr.Replace("System.Int32", "int");
    $typeStr = $typeStr.Replace("Int32", "int");

    return $typeStr;
}


# Process the list return type
function Process-ListType
{
    param([Type] $rt, [System.String] $name)

    $result = $null;

    if ($rt -eq $null)
    {
        return $result;
    }

    $xml = '<Name>' + $rt.FullName + '</Name>';
    $xml += '<ViewSelectedBy><TypeName>' + $rt.FullName + '</TypeName></ViewSelectedBy>' + [System.Environment]::NewLine;
    $xml += '<ListControl><ListEntries><ListEntry><ListItems>' + [System.Environment]::NewLine;

    $itemLabel = $itemName = $rt.Name;
    $xml += "<ListItem><Label>${itemName}</Label><ScriptBlock>[Newtonsoft.Json.JsonConvert]::SerializeObject(" + "$" + "_,  [Newtonsoft.Json.Formatting]::Indented)</ScriptBlock></ListItem>" + [System.Environment]::NewLine;
    $xml += '</ListItems></ListEntry></ListEntries></ListControl>' + [System.Environment]::NewLine;
    $xml = '<View>' + [System.Environment]::NewLine + $xml + '</View>' + [System.Environment]::NewLine;

    # Write-Verbose ("Xml: " + $xml);

    return $xml;
}

# Process the return type
function Process-ReturnType
{
    param([Type] $rt, [System.Array] $allrt)

    $result = "";

    if ($rt -eq $null)
    {
        return @($result, $allrt);
    }

    if ($allrt.Contains($rt.Name))
    {
        return @($result, $allrt);
    }

    $allrt += $rt.Name;

    if ($rt.Name -like '*LongRunning*' -or $rt.Name -like '*computeoperationresponse*' -or $rt.Name -like '*AzureOperationResponse*')
    {
        return @($result, $allrt);
    }

    $xml = '<Name>' + $rt.FullName + '</Name>';
    $xml += '<ViewSelectedBy><TypeName>' + $rt.FullName + '</TypeName></ViewSelectedBy>' + [System.Environment]::NewLine;
    $xml += '<ListControl><ListEntries><ListEntry><ListItems>' + [System.Environment]::NewLine;

    $props = $rt.GetProperties([System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::Static);

    foreach ($pr1 in $props)
    {        
        $typeStr = Get-ProperTypeName $pr1.PropertyType;
        $itemLabel = $itemName = $pr1.Name;

        if ($typeStr -eq 'string' `
        -or $typeStr -eq 'string[]' `
        -or $typeStr -eq 'uint' `
        -or $typeStr -eq 'uint?' `
        -or $typeStr -eq 'int' `
        -or $typeStr -eq 'int?' `
        -or $typeStr -eq 'bool' `
        -or $typeStr -eq 'bool?' `
        -or $typeStr -eq 'DateTime' `
        -or $typeStr -eq 'DateTime?' `
        -or $typeStr -eq 'DateTimeOffset' `
        -or $typeStr -eq 'DateTimeOffset?' `
        -or $typeStr -eq 'HttpStatusCode' )
        {
           $xml += "<ListItem><Label>${itemLabel}</Label><PropertyName>${itemName}</PropertyName></ListItem>" + [System.Environment]::NewLine;
        }
        elseif ($typeStr.StartsWith('IList') `
        -or $typeStr.StartsWith('IDictionary'))
        {
           $elementType = $pr1.PropertyType.GenericTypeArguments[0];

           if (-not $elementType.FullName.Contains("String"))
           {
                if (-not $allrt.Contains($elementType.Name))
                {
                     $allrt += $elementType.Name;
                     $addxml = Process-ListType -rt $pr1.PropertyType.GenericTypeArguments[0] -name ${itemName};
                }
           }

           $xml += "<ListItem><Label>${itemLabel}.Count</Label><ScriptBlock> if (" + "$" + "_.${itemName} -eq $" + "null) { 0 } else { $" + "_.${itemName}.Count }</ScriptBlock></ListItem>" + [System.Environment]::NewLine;
           $xml += "<ListItem><Label>${itemLabel}</Label><ScriptBlock> foreach ($" + "item in $" + "_.${itemName}) { [Newtonsoft.Json.JsonConvert]::SerializeObject(" + "$" + "item,  [Newtonsoft.Json.Formatting]::Indented) } </ScriptBlock></ListItem>" + [System.Environment]::NewLine;
        }
        else
        {
           $xml += "<ListItem><Label>${itemLabel}</Label><ScriptBlock>[Newtonsoft.Json.JsonConvert]::SerializeObject(" + "$" + "_." + ${itemName} + ",  [Newtonsoft.Json.Formatting]::Indented)</ScriptBlock></ListItem>" + [System.Environment]::NewLine;
        }
    }

    $xml += '</ListItems></ListEntry></ListEntries></ListControl>' + [System.Environment]::NewLine;
    $xml = '<View>' + [System.Environment]::NewLine + $xml + '</View>' + [System.Environment]::NewLine;

    if (-not [System.String]::IsNullOrEmpty($addxml))
    {
        $xml += $addxml;
    }

    # Write-Verbose ("Xml: " + $xml);

    return @($xml, $allrt)
}

# Get proper type name
function Format-XML ([xml]$xml, $indent = 2)
{
    $StringWriter = New-Object System.IO.StringWriter;
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter;
    $xmlWriter.Formatting = "indented";
    $xmlWriter.Indentation = $Indent;
    $st = $xml.WriteContentTo($XmlWriter);
    $st = $XmlWriter.Flush();
    $st = $StringWriter.Flush();
    Write-Output $StringWriter.ToString();
}

function Write-XmlFormatFile
{
    param(
        [Parameter(Mandatory = $True)]
        $xmlFilePath
    )

    $xmlCommentHeader = '<!--' + [System.Environment]::NewLine;
    foreach ($cLine in $code_common_header)
    {
        $xmlCommentHeader += $cLine + [System.Environment]::NewLine;
    }
    $xmlCommentHeader += '-->' + [System.Environment]::NewLine;

    $xmlContent = [xml]($xmlCommentHeader + '<Configuration><ViewDefinitions>' + [System.Environment]::NewLine + $formatXml + '</ViewDefinitions></Configuration>' + [System.Environment]::NewLine);
    $node = $xmlContent.CreateXmlDeclaration('1.0', 'UTF-8', $null);
    $st = $xmlContent.InsertBefore($node, $xmlContent.ChildNodes[0]);

    $formattedXmlContent = Format-XML $xmlContent.OuterXml;
    $st = Set-Content -Force -Path $xmlFilePath -Value $formattedXmlContent;
    # Write-Verbose($formattedXmlContent);
}

# Sample: NewAzureVirtualMachineCreateParameters.cs
function Write-CLICommandFile
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$fileOutputFolder,

        [Parameter(Mandatory = $True)]
        $commandCodeLines
    )
    
    $fileFullPath = $fileOutputFolder + '/' + 'cli.js';

    Write-Output "=============================================";
    Write-Output("Writing CLI Command File: " + $new_line_str + $fileFullPath);
    Write-Output "=============================================";

    $codeContent = 
@"
/**
 * Copyright (c) Microsoft.  All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

'use strict';

var __ = require('underscore');
var fs = require('fs');
var jsonpatch = require('json-patch');
var util = require('util');

var profile = require('../../../util/profile');
var utils = require('../../../util/utils');

var $ = utils.getLocaleString;

function beautify(jsonText) {
    var obj = JSON.parse(jsonText);
    return JSON.stringify(obj, null, 2);
}

exports.init = function (cli) {

$commandCodeLines

};
"@;

    $st = Set-Content -Path $fileFullPath -Value $codeContent -Force;
}

# Code Generation Main Run
$outFolder += '/Generated';

$output = Get-ChildItem -Path $dllFolder | Out-String;

# Set-Content -Path ($outFolder + '/Output.txt');
# Write-Verbose "List items under the folder: $dllFolder"
# Write-Verbose $output;

$dllname = $client_library_namespace;
$dllfile = $dllname + '.dll';
$dllFileFullPath = $dllFolder + '\' + $dllfile;

if (-not (Test-Path -Path $dllFileFullPath))
{
    Write-Verbose "DLL file `'$dllFileFullPath`' not found. Exit.";
}
else
{
    $assembly = [System.Reflection.Assembly]::LoadFrom($dllFileFullPath);
    [System.Reflection.Assembly]::LoadWithPartialName("System.Collections.Generic");
    
    # All original types
    $types = $assembly.GetTypes();
    $filtered_types = Get-FilteredOperationTypes $types $dllname $operationNameFilter;

    # Write Base Cmdlet File
    $auto_base_cmdlet_name = 'ComputeAutomationBaseCmdlet';
    $baseCmdletFileFullName = $outFolder + '\' + "$auto_base_cmdlet_name.cs";
    $opNameList = ($filtered_types | select -ExpandProperty Name);
    $clientClassType = $types | where { $_.Namespace -eq $dllname -and $_.Name -eq 'IComputeManagementClient' };
    Write-BaseCmdletFile $baseCmdletFileFullName $opNameList $clientClassType;

    # PSArgument File
    $model_class_out_folder = $outFolder + '\Models';
    if (Test-Path -Path $model_class_out_folder)
    {
        $st = rmdir -Recurse -Force $model_class_out_folder;
    }
    $st = mkdir -Force $model_class_out_folder;
    $psargument_model_class_file_path = $model_class_out_folder + '\PSArgument.cs';
    Write-PSArgumentFile $psargument_model_class_file_path;

    $invoke_cmdlet_class_name = 'InvokeAzureComputeMethodCmdlet';
    $invoke_cmdlet_file_name = $outFolder + '\' + "$invoke_cmdlet_class_name.cs";
    $parameter_cmdlet_class_name = 'NewAzureComputeArgumentListCmdlet';
    $parameter_cmdlet_file_name = $outFolder + '\' + "$parameter_cmdlet_class_name.cs";
    $new_object_cmdlet_class_name = 'NewAzureComputeParameterObjectCmdlet';
    $new_object_cmdlet_file_name = $outFolder + '\' + "$new_object_cmdlet_class_name.cs";

    [System.Reflection.ParameterInfo[]]$parameter_type_info_list = @();
    $dynamic_param_method_code = @();
    $invoke_cmdlet_method_code = @();
    $parameter_cmdlet_method_code = @();
    $all_return_type_names = @();
    $formatXml = "";
    $cliCommandCodeMainBody = "";

    # Write Operation Cmdlet Files
    foreach ($ft in $filtered_types)
    {
        Write-Output '';
        Write-Output '=============================================';
        Write-Output $ft.Name;
        Write-Output '=============================================';
    
        $opShortName = Get-OperationShortName $ft.Name;
        $opOutFolder = $outFolder + '/' + $opShortName;
        if (Test-Path -Path $opOutFolder)
        {
            $st = rmdir -Recurse -Force $opOutFolder;
        }
        $st = mkdir -Force $opOutFolder;

        $methods = $ft.GetMethods();
        foreach ($mt in $methods)
        {
            if ($mt.Name.StartsWith('Begin') -and $mt.Name.Contains('ing'))
            {
                # Skip 'BeginXXX' Calls for Now...
                continue;
            }

            Write-Output ($new_line_str + $mt.Name.Replace('Async', ''));
            $outputs = Write-OperationCmdletFile $opOutFolder $opShortName $mt $invoke_cmdlet_class_name $parameter_cmdlet_class_name;
            if ($outputs.Count -ne $null)
            {
                $dynamic_param_method_code += $outputs[-4];
                $invoke_cmdlet_method_code += $outputs[-3];
                $parameter_cmdlet_method_code += $outputs[-2];
                $cliCommandCodeMainBody += $outputs[-1];
            }

            $returnTypeResult = Process-ReturnType -rt $mt.ReturnType.GenericTypeArguments[0] -allrt $all_return_type_names;
            $formatXml += $returnTypeResult[0];
            $all_return_type_names = $returnTypeResult[1];
        }

        Write-InvokeCmdletFile $invoke_cmdlet_file_name $invoke_cmdlet_class_name $auto_base_cmdlet_name $clientClassType $filtered_types $invoke_cmdlet_method_code $dynamic_param_method_code;
        Write-InvokeParameterCmdletFile $parameter_cmdlet_file_name $parameter_cmdlet_class_name $auto_base_cmdlet_name $clientClassType $filtered_types $parameter_cmdlet_method_code;
        Write-NewParameterObjectCmdletFile $new_object_cmdlet_file_name $new_object_cmdlet_class_name $auto_base_cmdlet_name $clientClassType $filtered_types $parameter_cmdlet_method_code;
    }

    # XML 
    $xmlFilePath = $outFolder + '\' + $code_common_namespace + '.format.generated.ps1xml';
    Write-Output "=============================================";
    Write-Output ('Writing XML Format File: ' + $new_line_str + $xmlFilePath);
    Write-Output "=============================================";
    Write-XmlFormatFile $xmlFilePath;

    # CLI
    if ($cliCommandFlavor -eq 'Verb')
    {
        Write-CLICommandFile $outFolder $cliCommandCodeMainBody;
    }

    Write-Output "=============================================";
    Write-Output "Finished.";
    Write-Output "=============================================";
}
