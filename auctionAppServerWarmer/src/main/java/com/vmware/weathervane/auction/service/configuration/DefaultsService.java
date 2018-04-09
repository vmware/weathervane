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
package com.vmware.weathervane.auction.service.configuration;

import com.vmware.weathervane.auction.model.defaults.AppInstanceDefaults;
import com.vmware.weathervane.auction.model.defaults.AppServerDefaults;
import com.vmware.weathervane.auction.model.defaults.ConfigurationManagerDefaults;
import com.vmware.weathervane.auction.model.defaults.CoordinationServerDefaults;
import com.vmware.weathervane.auction.model.defaults.DbServerDefaults;
import com.vmware.weathervane.auction.model.defaults.FileServerDefaults;
import com.vmware.weathervane.auction.model.defaults.IpManagerDefaults;
import com.vmware.weathervane.auction.model.defaults.LbServerDefaults;
import com.vmware.weathervane.auction.model.defaults.MsgServerDefaults;
import com.vmware.weathervane.auction.model.defaults.NosqlServerDefaults;
import com.vmware.weathervane.auction.model.defaults.ServiceDefaults;
import com.vmware.weathervane.auction.model.defaults.WebServerDefaults;

public interface DefaultsService {

	ServiceDefaults getDefaults();

	void setAppInstanceDefaults(AppInstanceDefaults server);
	void setConfigurationManagerDefaults(ConfigurationManagerDefaults server);
	void setCoordinationServerDefaults(CoordinationServerDefaults server);
	void setIpManagerDefaults(IpManagerDefaults ipManager);
	void setLbServerDefaults(LbServerDefaults lbServer);
	void setWebServerDefaults(WebServerDefaults webServer);
	void setAppServerDefaults(AppServerDefaults appServer);
	void setMsgServerDefaults(MsgServerDefaults msgServer);
	void setNosqlServerDefaults(NosqlServerDefaults nosqlServer);
	void setDbServerDefaults(DbServerDefaults dbServer);
	void setFileServerDefaults(FileServerDefaults fileServer);

	AppInstanceDefaults getAppInstanceDefaults();
	ConfigurationManagerDefaults getConfigurationManagerDefaults();
	CoordinationServerDefaults getCoordinationServerDefaults();
	IpManagerDefaults getIpManagerDefaults();
	LbServerDefaults getLbServerDefaults();
	WebServerDefaults getWebServerDefaults();
	AppServerDefaults getAppServerDefaults();
	MsgServerDefaults getMsgServerDefaults();
	NosqlServerDefaults getNosqlServerDefaults();
	DbServerDefaults getDbServerDefaults();
	FileServerDefaults getFileServerDefaults();

}
