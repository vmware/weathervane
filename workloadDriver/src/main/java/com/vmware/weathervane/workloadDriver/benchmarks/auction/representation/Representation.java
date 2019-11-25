/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author hrosenbe
 */
package com.vmware.weathervane.workloadDriver.benchmarks.auction.representation;

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
