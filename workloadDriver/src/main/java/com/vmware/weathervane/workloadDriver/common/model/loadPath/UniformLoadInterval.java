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
package com.vmware.weathervane.workloadDriver.common.model.loadPath;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "uniform")
public class UniformLoadInterval extends LoadInterval {
	private long users;
	
	public UniformLoadInterval() {
		
	}
	
	public UniformLoadInterval(UniformLoadInterval that) {
		this.users = that.users;
		this.setDuration(that.getDuration());
	}

	public UniformLoadInterval(long users, long duration) {
		this.users = users;
		this.setDuration(duration);
	}
	
	public long getUsers() {
		return users;
	}
	public void setUsers(long users) {
		this.users = users;
	}
	
	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("UniformLoadInterval: ");
		theStringBuilder.append("; duration: " + getDuration()); 
		theStringBuilder.append("; users: " + users); 
		
		return theStringBuilder.toString();
	}

}
