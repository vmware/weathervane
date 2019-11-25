/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core;

import java.net.URI;
import java.util.Map;

/**
 * The Simple URL is used to hold portions of a complete URI. The actual URI is
 * constructed elsewhere. The path and query strings can have variables in curly
 * braces, which can be substituted using the getters that take bindVars.
 * 
 * @author Hal
 * 
 */
public class SimpleUri {

	private String scheme;
	private String hostname;
	private Integer port;
	private String servletPath;
	private String path;
	private String queryString;

	public SimpleUri(URI uri) {
		this.scheme = uri.getScheme();
		this.hostname = uri.getHost();
		this.port = uri.getPort();
		this.servletPath  = null;
		this.path = uri.getPath();
		this.queryString = uri.getQuery();
	}
	
	public SimpleUri(String scheme, String hostname, Integer port, String servletPath, String path,
			String queryString) {
		if (scheme == null) {
			throw new RuntimeException("Creating SimpleUri.  scheme cannot be null");
		}
		if (hostname == null) {
			throw new RuntimeException("Creating SimpleUri.  hostname cannot be null");
		}

		this.scheme = scheme;
		this.hostname = hostname;
		this.port = port;
		this.servletPath = servletPath;
		this.path = path;
		this.queryString = queryString;
	}

	public String getUriString() {
		return getUriString(null);
	}

	public String getUriString(Map<String, String> bindVariables) {
		
		String realPort;
		if (port == null) {
			realPort = "";
		} else {
			realPort = ":" + port.toString();
		}
		
		String realServletPath;
		if ((servletPath == null) || (servletPath.equals(""))) {
			realServletPath = "";
		} else {
			realServletPath = "/" + servletPath;
		}
		
		String realPath;
		if ((path == null) || (path.equals(""))) {
			realPath = "";
		} else {
			realPath = "/" + doReplace(path, bindVariables);
		}

		
		String realQueryString;
		if ((queryString == null) || (queryString.equals(""))) {
			realQueryString = "";
		} else {
			realQueryString = "?" + doReplace(queryString, bindVariables);
		}
		
		
		return scheme + "://" + hostname + realPort + realServletPath + realPath + realQueryString;

	}

	public String getScheme() {
		return scheme;
	}

	public void setScheme(String scheme) {
		this.scheme = scheme;
	}

	public String getPath() {
		return path;
	}

	public String getPath(Map<String, String> bindVariables) {
		return doReplace(path, bindVariables);
	}

	public void setPath(String path) {
		this.path = path;
	}

	public String getQueryString() {
		return queryString;
	}

	public String getQueryString(Map<String, String> bindVariables) {
		return doReplace(queryString, bindVariables);
	}

	public void setQueryString(String queryString) {
		this.queryString = queryString;
	}

	public String getHostname() {
		return hostname;
	}

	public void setHostname(String hostname) {
		this.hostname = hostname;
	}

	public int getPort() {
		return port;
	}

	public void setPort(int port) {
		this.port = port;
	}

	public String getServletPathString() {
		return servletPath;
	}

	public void setServletPathString(String contextPathString) {
		this.servletPath = contextPathString;
	}

	private String doReplace(String str, Map<String, String> bindVariables) {
		String resultString = str;
		if (bindVariables != null) {
			for (String varName : bindVariables.keySet()) {
				String varWithBrackets = "{" + varName + "}";
				resultString = resultString.replace(varWithBrackets, bindVariables.get(varName));
			}
		}
		return resultString;
	}

}
