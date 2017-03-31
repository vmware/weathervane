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
package com.vmware.weathervane.workloadDriver.common.web.service;

import java.net.UnknownHostException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.vmware.weathervane.workloadDriver.common.exceptions.RunNotInitializedException;
import com.vmware.weathervane.workloadDriver.common.exceptions.TooManyUsersException;
import com.vmware.weathervane.workloadDriver.common.model.Run;
import com.vmware.weathervane.workloadDriver.common.representation.ActiveUsersResponse;
import com.vmware.weathervane.workloadDriver.common.representation.ChangeUsersMessage;

@Service
public class RunServiceImpl implements RunService {
	private static final Logger logger = LoggerFactory.getLogger(RunServiceImpl.class);

	private Run theRun = null;
	
	private boolean isInitialized = false;
	private boolean isStarted = false;
	
	@Override
	public void setRun(Run theRun) {
		this.theRun = theRun;
	}
	
	@Override
	public void initialize() throws UnknownHostException {
		logger.debug("initialize");
		if (theRun == null) {
			throw new RunNotInitializedException("Run configuration must be set before initializing");
		}
		
		theRun.initialize();
		isInitialized = true;
	}
	
	@Override
	public void start() {
		logger.debug("start");
		if (theRun == null) {
			throw new RunNotInitializedException("Run configuration must be set and initialized before starting");
		}
		if (!isInitialized) {
			throw new RunNotInitializedException("Run configuration must be initialized before starting");
		}

		theRun.start();
		isStarted = true;
		
	}
	
	@Override
	public void stop() {
		logger.debug("stop");
		if (theRun == null) {
			throw new RunNotInitializedException("Run configuration must be set and started before stopping");
		}
		if (!isStarted) {
			throw new RunNotInitializedException("Run configuration must be started before stopping");
		}

		theRun.stop();
		
	}
	
	@Override
	public void shutdown() {
		logger.debug("shutdown");
		if (theRun == null) {
			throw new RunNotInitializedException("Run configuration must be set and started before stopping");
		}
		if (!isStarted) {
			throw new RunNotInitializedException("Run configuration must be started before stopping");
		}

		theRun.shutdown();
		
	}
	
	@Override
	public boolean isStarted() {
		return isStarted;
		
	}	
	
	@Override
	public boolean isUp() {
		return true;
		
	}

	@Override
	public void changeActiveUsers(String workloadName, long numUsers) throws TooManyUsersException {
		theRun.changeActiveUsers(workloadName, numUsers);
	}

	@Override
	public ActiveUsersResponse getNumActiveUsers() {
		return theRun.getNumActiveUsers();
	}
	
}
