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
package com.vmware.weathervane.auction.util;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.net.UnknownHostException;
import java.nio.file.Files;
import java.nio.file.Paths;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.jcabi.ssh.Shell;
import com.jcabi.ssh.SSH;

public class SshUtils {
	private static final Logger logger = LoggerFactory.getLogger(SshUtils.class);

	private static final String privateKeyFile = "/root/.ssh/id_rsa";

	private static final String privateKey;

	static {
		String tmpKey = "";
		try {
			tmpKey = new String(Files.readAllBytes(Paths.get(privateKeyFile)));
			logger.debug("Read privateKey: " + tmpKey);
		} catch (IOException e) {
			logger.warn("Couldn't read private key file " + privateKeyFile + ": " + e.getMessage());
		}
		privateKey = tmpKey;
	}

	public static String SshExec(String hostname, String command) {
		Shell shell;
		try {
			shell = new SSH(hostname, 22, "root", privateKey);
			return new Shell.Plain(shell).exec(command);
		} catch (UnknownHostException e) {
			logger.warn("SshExec caught UnknownHostException exception: " + e.getMessage());
			return "";
		} catch (IOException e) {
			logger.warn("SshExec caught IOExceptionexception: " + e.getMessage());
			return "";
		}
	}

	public static int ScpTo(String localFileName, String hostname, String remoteFileName) {
		logger.debug("ScpTo: " + localFileName + " to root@" + hostname + ":" + remoteFileName );
		Shell shell;
		FileInputStream fis = null;
		try {
			File localFile = new File(localFileName);
			shell = new SSH(hostname, 22, "root", privateKey);
			ByteArrayOutputStream outStream = new ByteArrayOutputStream();
			ByteArrayOutputStream errStream = new ByteArrayOutputStream();
			fis = new FileInputStream(localFile);
			int retCode = new Shell.Verbose(new Shell.Safe(shell)).exec("cat > " + remoteFileName,
					fis, outStream, errStream);
			logger.debug("ScpTo: " + localFileName + " to root@" + hostname + ":" + remoteFileName + " returned " + retCode);
			if (outStream.size() > 0) {
				String outString = new String(outStream.toByteArray());
				logger.debug("scpTo ssh operation returned info: " + outString);
			}
			if (errStream.size() > 0) {
				String outString = new String(errStream.toByteArray());
				logger.warn("scpTo ssh operation returned info: " + outString);
			}
			return retCode;	
		} catch (UnknownHostException e) {
			logger.warn("SshExec caught UnknownHostException exception: " + e.getMessage());
			return -1;
		} catch (IOException e) {
			logger.warn("SshExec caught IOExceptionexception: " + e.getMessage());
			return -1;
		} finally {
			if (fis != null)
				try {
					fis.close();
				} catch (IOException e) {
					logger.warn("Can't close fileInputStream: " + e.getMessage());
				}
		}
	}

	public static int ScpStringTo(String contents, String hostname, String remoteFileName) {
		Shell shell;
		try {
			shell = new SSH(hostname, 22, "root", privateKey);
			ByteArrayOutputStream outStream = new ByteArrayOutputStream();
			ByteArrayOutputStream errStream = new ByteArrayOutputStream();
			int retCode =  new Shell.Verbose(new Shell.Safe(shell)).exec("cat > " + remoteFileName,
					new ByteArrayInputStream(contents.getBytes()), outStream, errStream);
			logger.debug("ScpStringTo: to root@" + hostname + ":" + remoteFileName + " returned " + retCode);
			if (outStream.size() > 0) {
				String outString = new String(outStream.toByteArray());
				logger.debug("scpStringTo ssh operation returned info: " + outString);
			}
			if (errStream.size() > 0) {
				String outString = new String(errStream.toByteArray());
				logger.warn("scpStringTo ssh operation returned info: " + outString);
			}
			return retCode;
		} catch (UnknownHostException e) {
			logger.warn("SshExec caught UnknownHostException exception: " + e.getMessage());
			return -1;
		} catch (IOException e) {
			logger.warn("SshExec caught IOExceptionexception: " + e.getMessage());
			return -1;
		}
	}
}
