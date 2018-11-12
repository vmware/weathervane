package com.vmware.weathervane.auction.service;

import org.springframework.stereotype.Service;

import com.vmware.weathervane.auction.exception.DuplicateRunConfigurationException;
import com.vmware.weathervane.auction.model.RunConfiguration;

@Service
public class RunConfigurationService {
	/*
	 * Might have a map or database or services.  For a start just have one.
	 */
	private RunConfiguration runConfiguration;

	public RunConfiguration getRunConfiguration() {
		return runConfiguration;
	}

	public void setRunConfiguration(RunConfiguration runConfiguration) throws DuplicateRunConfigurationException {
		this.runConfiguration = runConfiguration;
	}

}
