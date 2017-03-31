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
package com.vmware.weathervane.auction.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import net.sf.ehcache.CacheException;
import net.sf.ehcache.Ehcache;
import net.sf.ehcache.Element;
import net.sf.ehcache.event.CacheEventListener;

public class AuthTokenCacheEventListener implements CacheEventListener {
	private static final Logger logger = LoggerFactory.getLogger(AuthTokenCacheEventListener.class);


	@Override
	public void notifyElementRemoved(Ehcache cache, Element element) throws CacheException {
		logger.debug("Element removed from " + cache.getName() + " with key " + element.getKey());
	}

	@Override
	public void notifyElementPut(Ehcache cache, Element element) throws CacheException {
		logger.debug("Element put in " + cache.getName() + " with key " + element.getKey());
	}

	@Override
	public void notifyElementUpdated(Ehcache cache, Element element) throws CacheException {
		logger.debug("Element updated in " + cache.getName() + " with key " + element.getKey());
	}

	@Override
	public void notifyElementExpired(Ehcache cache, Element element) {
		logger.debug("Element expired in " + cache.getName() + " with key " + element.getKey());
	}

	@Override
	public void notifyElementEvicted(Ehcache cache, Element element) {
		logger.debug("Element evicted in " + cache.getName() + " with key " + element.getKey());
	}

	@Override
	public void notifyRemoveAll(Ehcache cache) {
		logger.debug("Remove all on cache " + cache.getName() );		
	}

	@Override
	public void dispose() {
	}
	
	@Override
	public Object clone(){
	    throw new UnsupportedOperationException("Not supported yet.");
	  }

}
