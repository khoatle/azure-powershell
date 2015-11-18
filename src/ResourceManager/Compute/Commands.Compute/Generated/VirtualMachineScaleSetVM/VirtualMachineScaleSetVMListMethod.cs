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

using Microsoft.Azure;
using Microsoft.Azure.Commands.Compute.Automation.Models;
using Microsoft.Azure.Management.Compute;
using Microsoft.Azure.Management.Compute.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;

namespace Microsoft.Azure.Commands.Compute.Automation
{
    public partial class InvokeAzureComputeMethodCmdlet : ComputeAutomationBaseCmdlet
    {
        protected object CreateVirtualMachineScaleSetVMListDynamicParameters()
        {
            dynamicParameters = new RuntimeDefinedParameterDictionary();
            var pExpandExpression = new RuntimeDefinedParameter();
            pExpandExpression.Name = "ExpandExpression";
            pExpandExpression.ParameterType = typeof(string);
            pExpandExpression.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByDynamicParameters",
                Position = 1,
                Mandatory = false
            });
            pExpandExpression.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add("ExpandExpression", pExpandExpression);

            var pFilterExpression = new RuntimeDefinedParameter();
            pFilterExpression.Name = "FilterExpression";
            pFilterExpression.ParameterType = typeof(string);
            pFilterExpression.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByDynamicParameters",
                Position = 2,
                Mandatory = false
            });
            pFilterExpression.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add("FilterExpression", pFilterExpression);

            var pResourceGroupName = new RuntimeDefinedParameter();
            pResourceGroupName.Name = "ResourceGroupName";
            pResourceGroupName.ParameterType = typeof(string);
            pResourceGroupName.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByDynamicParameters",
                Position = 3,
                Mandatory = false
            });
            pResourceGroupName.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add("ResourceGroupName", pResourceGroupName);

            var pSelectExpression = new RuntimeDefinedParameter();
            pSelectExpression.Name = "SelectExpression";
            pSelectExpression.ParameterType = typeof(string);
            pSelectExpression.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByDynamicParameters",
                Position = 4,
                Mandatory = false
            });
            pSelectExpression.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add("SelectExpression", pSelectExpression);

            var pVirtualMachineScaleSetName = new RuntimeDefinedParameter();
            pVirtualMachineScaleSetName.Name = "VirtualMachineScaleSetName";
            pVirtualMachineScaleSetName.ParameterType = typeof(string);
            pVirtualMachineScaleSetName.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByDynamicParameters",
                Position = 5,
                Mandatory = false
            });
            pVirtualMachineScaleSetName.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add("VirtualMachineScaleSetName", pVirtualMachineScaleSetName);

            var pArgumentList = new RuntimeDefinedParameter();
            pArgumentList.Name = "ArgumentList";
            pArgumentList.ParameterType = typeof(object[]);
            pArgumentList.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByStaticParameters",
                Position = 6,
                Mandatory = true
            });
            pArgumentList.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add("ArgumentList", pArgumentList);

            return dynamicParameters;
        }

        protected void ExecuteVirtualMachineScaleSetVMListMethod(object[] invokeMethodInputParameters)
        {
            var parameters = new VirtualMachineScaleSetVMListParameters();
            var pExpandExpression = (string) ParseParameter(invokeMethodInputParameters[0]);
            parameters.ExpandExpression = string.IsNullOrEmpty(pExpandExpression) ? null : pExpandExpression;
            var pFilterExpression = (string) ParseParameter(invokeMethodInputParameters[1]);
            parameters.FilterExpression = string.IsNullOrEmpty(pFilterExpression) ? null : pFilterExpression;
            var pResourceGroupName = (string) ParseParameter(invokeMethodInputParameters[2]);
            parameters.ResourceGroupName = string.IsNullOrEmpty(pResourceGroupName) ? null : pResourceGroupName;
            var pSelectExpression = (string) ParseParameter(invokeMethodInputParameters[3]);
            parameters.SelectExpression = string.IsNullOrEmpty(pSelectExpression) ? null : pSelectExpression;
            var pVirtualMachineScaleSetName = (string) ParseParameter(invokeMethodInputParameters[4]);
            parameters.VirtualMachineScaleSetName = string.IsNullOrEmpty(pVirtualMachineScaleSetName) ? null : pVirtualMachineScaleSetName;

            var result = VirtualMachineScaleSetVMClient.List(parameters);
            WriteObject(result);
        }
    }

    public partial class NewAzureComputeArgumentListCmdlet : ComputeAutomationBaseCmdlet
    {
        protected PSArgument[] CreateVirtualMachineScaleSetVMListParameters()
        {
            var pExpandExpression = string.Empty;
            var pFilterExpression = string.Empty;
            var pResourceGroupName = string.Empty;
            var pSelectExpression = string.Empty;
            var pVirtualMachineScaleSetName = string.Empty;

            return ConvertFromObjectsToArguments(
                 new string[] { "ExpandExpression", "FilterExpression", "ResourceGroupName", "SelectExpression", "VirtualMachineScaleSetName" },
                 new object[] { pExpandExpression, pFilterExpression, pResourceGroupName, pSelectExpression, pVirtualMachineScaleSetName });
        }
    }

    [Cmdlet("Get", "AzureRmVmssVMList", DefaultParameterSetName = "InvokeByDynamicParameters")]
    public partial class GetAzureRmVMSSVMList : InvokeAzureComputeMethodCmdlet
    {
        public GetAzureRmVMSSVMList()
        {
            this.MethodName = "VirtualMachineScaleSetVMList";
        }

        public override string MethodName { get; set; }

        protected override void ProcessRecord()
        {
            base.ProcessRecord();
        }

        public override object GetDynamicParameters()
        {
            dynamicParameters = new RuntimeDefinedParameterDictionary();
            var pExpandExpression = new RuntimeDefinedParameter();
            pExpandExpression.Name = "ExpandExpression";
            pExpandExpression.ParameterType = typeof(string);
            pExpandExpression.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByDynamicParameters",
                Position = 1,
                Mandatory = false
            });
            pExpandExpression.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add("ExpandExpression", pExpandExpression);

            var pFilterExpression = new RuntimeDefinedParameter();
            pFilterExpression.Name = "FilterExpression";
            pFilterExpression.ParameterType = typeof(string);
            pFilterExpression.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByDynamicParameters",
                Position = 2,
                Mandatory = false
            });
            pFilterExpression.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add("FilterExpression", pFilterExpression);

            var pResourceGroupName = new RuntimeDefinedParameter();
            pResourceGroupName.Name = "ResourceGroupName";
            pResourceGroupName.ParameterType = typeof(string);
            pResourceGroupName.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByDynamicParameters",
                Position = 3,
                Mandatory = false
            });
            pResourceGroupName.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add("ResourceGroupName", pResourceGroupName);

            var pSelectExpression = new RuntimeDefinedParameter();
            pSelectExpression.Name = "SelectExpression";
            pSelectExpression.ParameterType = typeof(string);
            pSelectExpression.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByDynamicParameters",
                Position = 4,
                Mandatory = false
            });
            pSelectExpression.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add("SelectExpression", pSelectExpression);

            var pVirtualMachineScaleSetName = new RuntimeDefinedParameter();
            pVirtualMachineScaleSetName.Name = "VirtualMachineScaleSetName";
            pVirtualMachineScaleSetName.ParameterType = typeof(string);
            pVirtualMachineScaleSetName.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByDynamicParameters",
                Position = 5,
                Mandatory = false
            });
            pVirtualMachineScaleSetName.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add("VirtualMachineScaleSetName", pVirtualMachineScaleSetName);

            var pArgumentList = new RuntimeDefinedParameter();
            pArgumentList.Name = "ArgumentList";
            pArgumentList.ParameterType = typeof(object[]);
            pArgumentList.Attributes.Add(new ParameterAttribute
            {
                ParameterSetName = "InvokeByStaticParameters",
                Position = 6,
                Mandatory = true
            });
            pArgumentList.Attributes.Add(new AllowNullAttribute());
            dynamicParameters.Add("ArgumentList", pArgumentList);

            return dynamicParameters;
        }
    }
}