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
package com.vmware.weathervane.workloadDriver.common.http;

import java.nio.charset.Charset;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import io.netty.channel.Channel;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.SimpleChannelInboundHandler;
import io.netty.channel.pool.FixedChannelPool;
import io.netty.handler.codec.http.FullHttpResponse;
import io.netty.handler.codec.http.HttpContent;
import io.netty.handler.codec.http.HttpHeaders;
import io.netty.handler.codec.http.HttpMethod;
import io.netty.handler.codec.http.HttpObject;
import io.netty.handler.codec.http.HttpRequest;
import io.netty.handler.codec.http.HttpResponse;
import io.netty.handler.codec.http.HttpResponseStatus;
import io.netty.handler.codec.http.LastHttpContent;
import io.netty.util.concurrent.Future;
import io.netty.util.concurrent.FutureListener;

public class ResponseInboundHandler extends SimpleChannelInboundHandler<HttpObject> {
	private static final Logger logger = LoggerFactory.getLogger(ResponseInboundHandler.class);

	private HttpTransport _httpTransport;
	private HttpRequest _httpRequest;
	private boolean _dropResponse;
	private HttpRequestCompleteCallback _callbackObject;
	private Channel _channel;
	private FixedChannelPool _pool;
	private ChannelCloseFutureListener _closeListener;
	private long _userId ;
	
	private HttpResponse _response = null;	
	
	public ResponseInboundHandler(HttpTransport httpTransport, HttpRequest httpRequest, 
			boolean dropResponse, HttpRequestCompleteCallback callbackObject, 
			Channel channel, FixedChannelPool pool, ChannelCloseFutureListener closeListener,
			long userId) {
		super();
		this._httpTransport = httpTransport;
		this._httpRequest = httpRequest;
		this._dropResponse = dropResponse;
		this._callbackObject = callbackObject;
		this._channel = channel;
		this._pool = pool;
		this._closeListener = closeListener;
		this._userId = userId;
	}

	@Override
	protected void channelRead0(ChannelHandlerContext ctx, HttpObject msg) throws Exception {

		if (msg instanceof FullHttpResponse) {
			/* 
			 * This is the full message.  Clean up and notify the callback
			 */
			if (_dropResponse) {
				logger.warn("Got a FullHttpResponse even though dropResponse==true");
			}
			
			_response =  (HttpResponse) msg;
			FullHttpResponse fullResponse = (FullHttpResponse) msg;
			
			logger.debug("channelRead: received FullHttpResponse status:" + fullResponse.status()
			+ " for userId = " + _userId + " request with url " + _httpRequest.uri());

			/*
			 * Stop listening for the close callback
			 */
			_channel.closeFuture().removeListener(_closeListener);
			
			/*
			 * Return the channel to the pool
			 */
			Future<Void> releaseFuture = _pool.release(_channel);
			
			if (fullResponse != null) {
				/*
				 * Get the cookies from the response for use in future requests
				 */
				_httpTransport.extractCookies(_response);

				/*
				 * Signal that the request is complete
				 */
				releaseFuture.addListener(new RequestCompletedCallback(fullResponse.status(), 
						fullResponse.headers(), fullResponse.content().toString(Charset.defaultCharset())));
			} 

		
		} else if (msg instanceof HttpResponse) {
			/*
			 * Save the response to return once all content has been received.
			 */
			_response = (HttpResponse) msg;

			logger.debug("channelRead: received HttpResponse for userId = " + _userId + ", status:" + _response.status()
						+ " for request with url " + _httpRequest.uri());

		} else if (msg instanceof LastHttpContent) {
			/* 
			 * This is the end of the message.  Clean up and notify the callback
			 */
			logger.debug("channelRead: received LastHttpContentfor userId = " + _userId + " for request with url " + _httpRequest.uri());
			if (!_dropResponse) {
				logger.warn("Got HttpContent even though dropResponse==false");
			}
			
			/*
			 * Stop listening for the close callback
			 */
			_channel.closeFuture().removeListener(_closeListener);
			
			/*
			 * Return the channel to the pool
			 */
			Future<Void> releaseFuture = _pool.release(_channel);
						
			if (_response != null) {
				/*
				 * Get the cookies from the response for use in future requests
				 */
				_httpTransport.extractCookies(_response);

				/*
				 * Once the channel is returned, signal that the request is complete
				 */
				releaseFuture.addListener(new RequestCompletedCallback(_response.status(), 
													_response.headers(), null));
			} else {
				logger.debug("channelRead got LastHttpContent with null response for userId " + _userId + " for request with url " + _httpRequest.uri());				
				throw new RuntimeException("ChannelRead got LastHttpContent with null response for request with url " + _httpRequest.uri() + ", userId = " + _userId);
			}


		} else if (msg instanceof HttpContent) {
			logger.debug("channelRead: received HttpContent for userId = " + _userId + " for request with url " + _httpRequest.uri());				
			if (!_dropResponse) {
				logger.warn("Got HttpContent even though dropResponse==false");
			}
			/*
			 * Should only get HttpContent in response to requests for which we don't 
			 * have any use for the content.  Otherwise we would have placed an HttpObjectAggregator
			 * into the pipeline before this handler.  As a result we can simply release the message. 
			 */
		} else {
			logger.debug("channelRead: received response with unknown type " + msg.getClass().getName() + " for request with url " + _httpRequest.uri());				
			throw new RuntimeException("channelRead: received response with unknown type " + msg.getClass().getName()
												+ " for request with url " + _httpRequest.uri() + ", userId = " + _userId);
		}
		
	}

	@Override
	public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
		logger.debug("exceptionCaught for request with url " + _httpRequest.uri());

		/*
		 * Call the registered callback
		 */
		logger.info("exceptionCaught reason = " + cause + ".  Was for for userId " + _userId + ", behaviour id = " + _callbackObject.getBehaviorId());
		if (logger.isDebugEnabled()) {
			cause.printStackTrace();
		}	
		
		/*
		 * Stop listening for the close callback
		 */
		_channel.closeFuture().removeListener(_closeListener);

		if (_channel.isOpen()) {
			_channel.close();
		}

		Future<Void> releaseFuture = _pool.release(_channel);
		releaseFuture.addListener(new FutureListener<Void>() {
			@Override
			public void operationComplete(Future<Void> future) throws Exception {
				_callbackObject.httpRequestFailed(cause, _httpRequest.method() == HttpMethod.GET);
			}
		});

	}
	
	private class RequestCompletedCallback implements FutureListener<Void> {
		private HttpResponseStatus _status;
		private HttpHeaders _headers;
		private String _content;

		public RequestCompletedCallback(HttpResponseStatus status, HttpHeaders headers, String content) {
			super();
			this._status = status;
			this._headers = headers;
			this._content = content;
		}

		@Override
		public void operationComplete(Future<Void> future) throws Exception {
			_callbackObject.httpRequestCompleted(_status, _headers, _content, _httpRequest.method() == HttpMethod.GET);
		}
	}

}
