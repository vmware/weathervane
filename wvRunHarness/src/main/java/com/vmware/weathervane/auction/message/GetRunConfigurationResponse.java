package com.vmware.weathervane.auction.message;

import com.vmware.weathervane.auction.model.RunConfiguration;

public class GetRunConfigurationResponse extends Message {
	private boolean success;
	private String message;
	private RunConfiguration runConfiguration;

	public boolean isSuccess() {
		return success;
	}

	public void setSuccess(boolean success) {
		this.success = success;
	}

	public String getMessage() {
		return message;
	}

	public void setMessage(String message) {
		this.message = message;
	}

	public RunConfiguration getRunConfiguration() {
		return runConfiguration;
	}

	public void setRunConfiguration(RunConfiguration runConfiguration) {
		this.runConfiguration = runConfiguration;
	}

}
