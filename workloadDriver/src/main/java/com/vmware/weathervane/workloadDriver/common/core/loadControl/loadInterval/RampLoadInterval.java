/*
Copyright (c) 2017 VMware, Inc. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "ramp")
public class RampLoadInterval extends LoadInterval {
	private Long startUsers = null;
	private Long endUsers = null;
	private Long timeStep = 15L;
	
	public Long getStartUsers() {
		return startUsers;
	}


	public void setStartUsers(Long startUsers) {
		this.startUsers = startUsers;
	}


	public Long getEndUsers() {
		return endUsers;
	}


	public void setEndUsers(Long endUsers) {
		this.endUsers = endUsers;
	}


	public Long getTimeStep() {
		return timeStep;
	}


	public void setTimeStep(Long timeStep) {
		this.timeStep = timeStep;
	}


	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("RampLoadInterval: ");
		theStringBuilder.append("; duration: " + getDuration()); 
		theStringBuilder.append("; startUsers: " + startUsers); 
		theStringBuilder.append("; endUsers: " + endUsers); 
		theStringBuilder.append("; timeStep: " + timeStep); 
		
		return theStringBuilder.toString();
	}

}
