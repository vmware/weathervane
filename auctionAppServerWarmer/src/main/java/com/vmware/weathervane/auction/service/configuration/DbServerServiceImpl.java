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

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.vmware.weathervane.auction.model.configuration.DbServer;
import com.vmware.weathervane.auction.model.defaults.DbServerDefaults;
import com.vmware.weathervane.auction.repository.DbServerRepository;
import com.vmware.weathervane.auction.service.exception.DuplicateServiceException;
import com.vmware.weathervane.auction.service.exception.ServiceNotFoundException;

@Service
public class DbServerServiceImpl implements DbServerService {
	
	@Autowired
	private DbServerRepository dbServerRepository;

	@Override
	public List<DbServer> getDbServers() {
		return dbServerRepository.findAll();
	}

	@Override
	public DbServer getDbServer(Long id) {
		return dbServerRepository.findOne(id);
	}
	
	@Override
	public DbServer addDbServer(DbServer dbServer) throws DuplicateServiceException {
		return dbServerRepository.save(dbServer);	
	}

	
	@Override
	public void configureDbServer(Long dbServerId, DbServerDefaults defaults) throws ServiceNotFoundException {
		DbServer dbServerConfig = dbServerRepository.findOne(dbServerId);
		
		String hostname = dbServerConfig.getHostName();
		
		
	}

}
