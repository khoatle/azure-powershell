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

using System;
using System.Collections.Generic;
using System.Management.Automation;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Azure.Management.Intune;
using Microsoft.Azure.Management.Intune.Models;
using Microsoft.Rest.Azure;
using Microsoft.WindowsAzure.Commands.ScenarioTest;
using Moq;
using Newtonsoft.Json;
using Xunit;
using Microsoft.Azure.Commands.Intune.Flagged;

namespace Commands.Intune.Test.UnitTests
{
    public class GetIntuneMAMFlaggedEnrolledAppsCmdletTests
    {
        private Mock<IIntuneResourceManagementClient> intuneClientMock;
        private Mock<ICommandRuntime> commandRuntimeMock;
        private GetIntuneMAMUserFlaggedEnrolledAppsCmdlet cmdlet;
        private Location expectedLocation;

        /// <summary>
        ///  C'tor for GetIntuneMAMUserFlaggedEnrolledAppsCmdlet class.
        /// </summary>
        public GetIntuneMAMFlaggedEnrolledAppsCmdletTests()
        {
            commandRuntimeMock = new Mock<ICommandRuntime>();
            intuneClientMock = new Mock<IIntuneResourceManagementClient>();

            cmdlet = new GetIntuneMAMUserFlaggedEnrolledAppsCmdlet();
            this.cmdlet.CommandRuntime = commandRuntimeMock.Object;
            this.cmdlet.IntuneClient = intuneClientMock.Object;

            // Set-up mock Location and mock the underlying service API method       
            AzureOperationResponse<Location> resLocation = new AzureOperationResponse<Location>();
            expectedLocation = new Location("mockHostName");
            resLocation.Body = expectedLocation;

            intuneClientMock.Setup(f => f.GetLocationByHostNameWithHttpMessagesAsync(It.IsAny<Dictionary<string, List<string>>>(), It.IsAny<CancellationToken>()))
                .Returns(Task.FromResult(resLocation));
        }

        /// <summary>
        /// Test to return valid item.
        /// </summary>
        [Fact]
        [Trait(Category.AcceptanceType, Category.CheckIn)]
        public void GetIntuneMAMFlaggedEnrolledApps_ReturnsValidItem_Test()
        {
            // Set up the expected Policy            
            string flaggedEnrolledApps = "{\r\n  \"value\": [\r\n    {\r\n      \"id\": \"/providers/Microsoft.Intune/locations/fef.bmsua01/flaggedUsers/f4058390-f6d0-459b-9c36-3cf9d88e87f5/flaggedEnrolledApps/04045141-9ec3-4ecd-a302-3efca2b0be54\",\r\n      \"name\": \"04045141-9ec3-4ecd-a302-3efca2b0be54\",\r\n      \"type\": \"Microsoft.Intune/locations/flaggedUsers/flaggedEnrolledApps\",\r\n      \"properties\": {\r\n        \"friendlyName\": \"OneDrive\",\r\n        \"deviceType\": \"TestIpad\",\r\n        \"platform\": \"ios\",\r\n        \"errors\": [\r\n          {\r\n            \"severity\": \"warning\",\r\n            \"errorCode\": \"err_rootedDevice\"\r\n          }\r\n        ],\r\n        \"lastModifiedTime\": \"2015-11-19T01:00:14.3952221\"\r\n      }\r\n    },\r\n    {\r\n      \"id\": \"/providers/Microsoft.Intune/locations/fef.bmsua01/flaggedUsers/f4058390-f6d0-459b-9c36-3cf9d88e87f5/flaggedEnrolledApps/197103ab-43cf-46e9-87cc-a59a375a9f6c\",\r\n      \"name\": \"197103ab-43cf-46e9-87cc-a59a375a9f6c\",\r\n      \"type\": \"Microsoft.Intune/locations/flaggedUsers/flaggedEnrolledApps\",\r\n      \"properties\": {\r\n        \"friendlyName\": \"Excel\",\r\n        \"deviceType\": \"TestIpad\",\r\n        \"platform\": \"ios\",\r\n        \"errors\": [\r\n          {\r\n            \"severity\": \"warning\",\r\n            \"errorCode\": \"err_rootedDevice\"\r\n          }\r\n        ],\r\n        \"lastModifiedTime\": \"2015-11-19T21:31:44.5201421\"\r\n      }\r\n    }\r\n  ]\r\n}";

            var expectedRespose = new AzureOperationResponse<IPage<FlaggedEnrolledApp>>();

            IPage<FlaggedEnrolledApp> expectedResultPage = new Page<FlaggedEnrolledApp>();

            expectedResultPage = JsonConvert.DeserializeObject<Page<FlaggedEnrolledApp>>(flaggedEnrolledApps, intuneClientMock.Object.DeserializationSettings);

            expectedRespose.Body = expectedResultPage;

            // Set up the mock methods
            intuneClientMock.Setup(f => f.GetMAMUserFlaggedEnrolledAppsWithHttpMessagesAsync(
                    expectedLocation.HostName,
                    It.IsAny<string>(),
                    It.IsAny<string>(),
                    It.IsAny<int?>(),
                    It.IsAny<string>(),
                    It.IsAny<Dictionary<string, List<string>>>(),
                    It.IsAny<CancellationToken>()))
                .Returns(Task.FromResult(expectedRespose));

            intuneClientMock.Setup(f => f.GetMAMUserFlaggedEnrolledAppsNextWithHttpMessagesAsync(
                    It.IsAny<string>(),
                    It.IsAny<Dictionary<string, List<string>>>(), It.IsAny<CancellationToken>()))
                .Returns(Task.FromResult(expectedRespose));

            commandRuntimeMock.Setup(m => m.ShouldProcess(It.IsAny<string>(), It.IsAny<string>()))
                .Returns(() => true);

            // Set cmdline args and execute the cmdlet
            this.cmdlet.ExecuteCmdlet();

            // Verify the result
            commandRuntimeMock.Verify(f => f.WriteObject(expectedResultPage, true), Times.Once());
        }
    }
}
