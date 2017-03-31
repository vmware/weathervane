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
package com.vmware.weathervane.auction.model.configuration;

import javax.persistence.Entity;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.vmware.weathervane.auction.model.defaults.ConfigurationManagerDefaults;

@Entity
@JsonIgnoreProperties(ignoreUnknown=true)
public class ConfigurationManager extends Service {
	
	private String configurationManagerImpl;
	private Integer webConfigInternalPort;
	private Integer webConfigPort;


	public Integer getWebConfigInternalPort() {
		return webConfigInternalPort;
	}

	public void setWebConfigInternalPort(Integer webConfigInternalPort) {
		this.webConfigInternalPort = webConfigInternalPort;
	}

	public Integer getWebConfigPort() {
		return webConfigPort;
	}

	public void setWebConfigPort(Integer webConfigPort) {
		this.webConfigPort = webConfigPort;
	}

	public String getConfigurationManagerImpl() {
		return configurationManagerImpl;
	}

	public void setConfigurationManagerImpl(String configurationManagerImpl) {
		this.configurationManagerImpl = configurationManagerImpl;
	}

	public ConfigurationManager mergeDefaults(final ConfigurationManagerDefaults defaults) {
		ConfigurationManager mergedConfigurationManager = (ConfigurationManager) super.mergeDefaults(this, defaults);;
		mergedConfigurationManager.setConfigurationManagerImpl(configurationManagerImpl != null ? configurationManagerImpl : defaults.getConfigurationManagerImpl());

		return mergedConfigurationManager;
	}
	
    @Override
    public boolean equals(Object obj) {
       if (!(obj instanceof ConfigurationManager))
            return false;
        if (obj == this)
            return true;

        ConfigurationManager rhs = (ConfigurationManager) obj;

        if (this.getId().equals(rhs.getId())) {
        	return true;
        } else {
        	return false;
        }
    }

}
