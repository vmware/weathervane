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
/**
 * 
 *
 * @author hrosenbe
 */
package com.vmware.weathervane.auction.representation;

import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * @author hrosenbe
 * 
 */
public class Representation {

	public enum RestAction {
		CREATE, READ, UPDATE, DELETE
	};
	
	/*
	 * The links maps a unique identifier for an entity type-name to a list of
	 * entity instances for that entity type. The list entry is a map from a RESTful
	 * action to the link for that action.
	 */
	protected Map<String, List<Map<RestAction, String>>> links = new HashMap<String, List<Map<RestAction, String>>>();


	public Map<String, List<Map<RestAction, String>>> getLinks() {
		return links;
	}

	protected void addLinkEntity(String entity) {
		links.put(entity, new LinkedList<Map<RestAction, String>>());
	}

	protected void addLinksForEntity(String entity, Map<RestAction, String> entityLinksMap) {
		if (!links.containsKey(entity)) {
			addLinkEntity(entity);
		}

		List<Map<RestAction, String>> entityLinks = links.get(entity);

		entityLinks.add(entityLinksMap);
	}

	protected static String replaceTokens(String text, Map<String, String> replacements) {
		Pattern pattern = Pattern.compile("\\{(.+?)\\}");
		Matcher matcher = pattern.matcher(text);
		StringBuffer buffer = new StringBuffer();
		while (matcher.find()) {
			String replacement = replacements.get(matcher.group(1));
			if (replacement != null) {
				// matcher.appendReplacement(buffer, replacement);
				// see comment
				matcher.appendReplacement(buffer, "");
				buffer.append(replacement);
			}
		}
		matcher.appendTail(buffer);
		return buffer.toString();
	}
	
}
