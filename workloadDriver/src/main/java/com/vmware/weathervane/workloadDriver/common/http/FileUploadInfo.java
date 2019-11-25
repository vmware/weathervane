/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.http;

import java.io.File;

public class FileUploadInfo {
	private File _file;
	private String _name;
	private String _contentType;
	private boolean _isText;

	
	public FileUploadInfo(File _file, String _name, String _contentType, boolean _isText) {
		super();
		this._file = _file;
		this._name = _name;
		this._contentType = _contentType;
		this._isText = _isText;
	}


	public File getFile() {
		return _file;
	}


	public String getName() {
		return _name;
	}


	public String getContentType() {
		return _contentType;
	}


	public boolean isText() {
		return _isText;
	}

}
