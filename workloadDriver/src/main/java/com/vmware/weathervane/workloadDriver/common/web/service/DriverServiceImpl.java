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

import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.vmware.weathervane.workloadDriver.common.exceptions.DuplicateRunException;
import com.vmware.weathervane.workloadDriver.common.exceptions.RunNotInitializedException;
import com.vmware.weathervane.workloadDriver.common.model.Workload;
import com.vmware.weathervane.workloadDriver.common.model.Workload.WorkloadState;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeWorkloadMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsIntervalCompleteMessage;

@Service
public class DriverServiceImpl implements DriverService {
	private static final Logger logger = LoggerFactory.getLogger(DriverServiceImpl.class);

	private Map<String, Map<String, Workload>> runNameToWorkloadNameToWorkloadMap = new HashMap<String, Map<String, Workload>>();
	
	@Override
	public void addRun(String runName) throws DuplicateRunException {
		logger.debug("addRun runName = " + runName);

		if (!runNameToWorkloadNameToWorkloadMap.containsKey(runName)) {
			runNameToWorkloadNameToWorkloadMap.put(runName, new HashMap<String, Workload>());
		}
	}
	
	@Override
	public void removeRun(String runName) {
		runNameToWorkloadNameToWorkloadMap.remove(runName);
	}
	
	@Override
	public void addWorkload(String runName, String workloadName, Workload theWorkload) throws DuplicateRunException {
		logger.debug("addWorkload: runName = " + runName + ", workloadName = " + workloadName );
		if (!runNameToWorkloadNameToWorkloadMap.containsKey(runName)) {
			logger.warn("addWorkload: runName = " + runName + ", workloadName = " + workloadName 
					+ ": Run has not been added to this node");
			throw new RunNotInitializedException("Run " + runName + " has not been added to this node.");
		}
		Map<String, Workload> workloadMap = runNameToWorkloadNameToWorkloadMap.get(runName);
		
		if (workloadMap.containsKey(workloadName)) {
			logger.warn("addWorkload: runName = " + runName + ", workloadName = " + workloadName 
					+ ": Workload is already loaded");
			throw new DuplicateRunException("Workload " + workloadName + " is already loaded.");
		}
		theWorkload.setState(WorkloadState.PENDING);
		
		workloadMap.put(workloadName, theWorkload);
	}

	@Override
	public void initializeWorkload(String runName, String workloadName, InitializeWorkloadMessage initializeWorkloadMessage) {
		logger.debug("initializeWorkload: runName = " + runName + ", workloadName = " + workloadName );
		if (!runNameToWorkloadNameToWorkloadMap.containsKey(runName)) {
			logger.warn("initializeWorkload: runName = " + runName + ", workloadName = " + workloadName 
					+ ": Run has not been added to this node");
			throw new RunNotInitializedException("Run " + runName + " has not been added to this node.");
		}
		Map<String, Workload> workloadMap = runNameToWorkloadNameToWorkloadMap.get(runName);
		Workload workload = workloadMap.get(workloadName);
		if (workload == null) {
			logger.warn("initializeWorkload: runName = " + runName + ", workloadName = " + workloadName 
					+ ": Workload does not exist on this node.");
			throw new RunNotInitializedException("Workload " + workloadName + " does not exist on this node");
		}
		workload.initializeNode(initializeWorkloadMessage);
	}

	@Override
	public void stopWorkload(String runName, String workloadName) {
		if (!runNameToWorkloadNameToWorkloadMap.containsKey(runName)) {
			throw new RunNotInitializedException("Run " + runName + " has not been added to this node.");
		}
		Map<String, Workload> workloadMap = runNameToWorkloadNameToWorkloadMap.get(runName);
		Workload workload = workloadMap.get(workloadName);
		workload.stopNode();
	}

	@Override
	public void changeActiveUsers(String runName, String workloadName, long activeUsers) {
		if (!runNameToWorkloadNameToWorkloadMap.containsKey(runName)) {
			throw new RunNotInitializedException("Run " + runName + " has not been added to this node.");
		}
		Map<String, Workload> workloadMap = runNameToWorkloadNameToWorkloadMap.get(runName);
		Workload workload = workloadMap.get(workloadName);
		if (workload == null) {
			throw new RunNotInitializedException("Workload " + workloadName + " does not exist on this node");
		}
		workload.setCurrentUsers(activeUsers);
	}

	@Override
	public void statsIntervalComplete(String runName, String workloadName,
			StatsIntervalCompleteMessage statsIntervalCompleteMessage) {
		logger.debug("statsIntervalComplete: runName = " + runName + ", workloadName = " + workloadName );
		if (!runNameToWorkloadNameToWorkloadMap.containsKey(runName)) {
			logger.warn("statsIntervalComplete: runName = " + runName + ", workloadName = " + workloadName 
					+ ": Run has not been added to this node");
			throw new RunNotInitializedException("Run " + runName + " has not been added to this node.");
		}
		Map<String, Workload> workloadMap = runNameToWorkloadNameToWorkloadMap.get(runName);
		Workload workload = workloadMap.get(workloadName);
		if (workload == null) {
			logger.warn("statsIntervalComplete: runName = " + runName + ", workloadName = " + workloadName 
					+ ": Workload does not exist on this node");
			throw new RunNotInitializedException("Workload " + workloadName + " does not exist on this node");
		}
		workload.statsIntervalComplete(statsIntervalCompleteMessage);
		
	}

	@Override
	public void exit(String runName) {
		if (!runNameToWorkloadNameToWorkloadMap.containsKey(runName)) {
			throw new RunNotInitializedException("Run " + runName + " has not been added to this node.");
		}
		/*
		 * Do the exit in the background after a wait to let the HTTP request completed
		 */
		Thread shutdownThread = new Thread(new ShutdownThreadRunner());
		shutdownThread.start();
	}
	

	private class ShutdownThreadRunner implements Runnable {

		@Override
		public void run() {
			try {
				Thread.sleep(10000);
			} catch (InterruptedException e) {
			}
			System.exit(0);
		}
		
	}
	
}
