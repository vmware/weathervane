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
package com.vmware.weathervane.workloadDriver.common.core;

import java.lang.reflect.Array;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.Random;
import java.util.Set;
import java.util.StringTokenizer;
import java.util.UUID;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.common.util.Holder;
import com.vmware.weathervane.workloadDriver.common.util.ResponseHolder;

/**
 * The state management is managed by a series of @Needs and @Contains
 * interfaces, where one type provides data that another type needs.
 * 
 * @author bcorrie
 * 
 */
public abstract class StateManagerStructs {

	private static final Logger logger = LoggerFactory.getLogger(StateManagerStructs.class);

	public interface AdminOperation {
	}

	/*** NEEDS/CONTAINS PROCESSING ***/

	public interface Contains {
	}

	public interface Needs {
	}

	/**
	 * 
	 * This interface is for operations that need data that is provided by the
	 * generator or other external source that is not a previous operation.
	 * 
	 * @author hrosenbe
	 * 
	 */
	public interface NeedsStatic {
	}

	/**
	 * The Removes interface is used to mark operations that remove previously
	 * collected data from the saved state of the generator
	 * 
	 * @author hrosenbe
	 */
	public interface Removes {
	}

	/**
	 * Special Needs interface which is not the same as the others. The others
	 * define a need for a particular kind of data, whereas this one defines a
	 * very specific need for a previous operation
	 */
	public interface NeedsPreviousOperation<T> {
		public Class<T> getOperationTypeNeeded();

		public void registerPreviousOperation(T operation);
	}

	/**
	 * 
	 * The Strategy interface is for strategy classes that provide a strategy
	 * for choosing data to include in a request or for choosing which
	 * operations to execute.
	 * 
	 * @author hrosenbe
	 */
	public interface Strategy {

	}

	/**
	 * Operations implement NeedsStrategy/ChoosesStrategy interfaces to control
	 * the provision of appropriate strategies to appropriate operations.
	 * 
	 */
	public interface NeedsStrategy {

	}

	public interface ChoosesStrategy {

	}

	/**
	 * Given an Operation, what kind of data does that operation need,
	 * represented by a List of @Needs interfaces
	 */
	@SuppressWarnings("unchecked")
	public List<Class<? extends Needs>> getNeedsInterfacesForType(
			Class<? extends Operation> type) {
		List<Class<? extends Needs>> result = new ArrayList<Class<? extends Needs>>();
		Class<?>[] interfaces = type.getInterfaces();
		for (Class<?> iface : interfaces) {
			if (Needs.class.isAssignableFrom(iface)) {
				result.add((Class<Needs>) iface);
			}
		}
		return result;
	}

	/**
	 * Given an Operation, what types of @Contains operation should have already
	 * been run, in order to satisfy the operations @Needs interfaces
	 */
	public List<Class<? extends Contains>> getPrevOperationsNeededByType(
			Class<? extends Operation> type) {
		List<Class<? extends Needs>> needsInterfaces = getNeedsInterfacesForType(type);
		List<Class<? extends Contains>> result = new ArrayList<Class<? extends Contains>>();
		for (Class<? extends Needs> c : needsInterfaces) {
			result.add(getNeedsDependencyType(c));
		}
		return result;
	}

	/**
	 * This method defines the associations between a @Needs interface and a @Contains
	 * interface In other words, an operation which @Needs something will need
	 * to find a previous operation that @Contains the same thing
	 */
	protected abstract Class<? extends Contains> getNeedsDependencyType(Class<? extends Needs> type);

	/*** LISTENER BASE CLASSES ***/

	public static class XListListenerConfig {
		public String _searchString;
		public char _terminator;
		public boolean _searchMultiple;
	}

	public static class XMapListenerConfig {
		public String _keySearchString;
		public char _keyTerminator;
		public String _valueSearchString;
		public char _valueTerminator;
		public boolean _searchMultiple;
		public boolean _keyPrecedesValue;
	}

	/**
	 * Knows how to parse HTML for certain strings, given a searchString and
	 * terminator char
	 */
	abstract public static class DataListener {
		
		abstract public boolean needsString(); 
		
		public String substringAndDeleteFromResponse(StringBuilder toParse, String toFind,
				char terminator) {
			int start = toParse.indexOf(toFind);
			String result = null;
			if (start > 0) {
				start += toFind.length();
				int end = toParse.indexOf("" + terminator, start);
				result = toParse.substring(start, end);
				toParse.delete(0, end);
			}
			return result;
		}
	}

	protected abstract static class XListListener<T> extends DataListener {
		private List<T> _data;

		protected XListListener(List<T> data) {
			_data = data;
		}

		protected void addKnownX(String value) {
			synchronized (_data) {
				if (validateValue(value)) {
					_data.add(convertStringToT(value));
				}
			}
		}

		protected void addX(T value) {
			synchronized (_data) {
				_data.add(value);
			}
		}

		protected void clear() {
			synchronized (_data) {
				_data.clear();
			}
		}

		/* Needs to deal with null */
		protected abstract T convertStringToT(String value);

		protected abstract boolean validateValue(String value);

		protected void findAndSetXFromResponse(String response, XListListenerConfig config) {
			StringBuilder toParse = new StringBuilder(response);
			synchronized (_data) {
				do {
					String item = substringAndDeleteFromResponse(toParse, config._searchString,
							config._terminator);
					if (item != null) {
						addKnownX(item);
					} else {
						break;
					}
				} while (config._searchMultiple);
			}
		}
	}

	protected abstract static class XSetListener<T> extends DataListener {
		private Set<T> _data;

		protected XSetListener(Set<T> data) {
			_data = data;
		}

		protected void addKnownX(String value) {
			synchronized (_data) {
				if (validateValue(value)) {
					_data.add(convertStringToT(value));
				}
			}
		}

		protected void addX(T value) {
			synchronized (_data) {
				_data.add(value);
			}
		}

		public boolean removeX(T value) {
			return _data.remove(value);
		}

		/* Needs to deal with null */
		protected abstract T convertStringToT(String value);

		protected abstract boolean validateValue(String value);

		protected void findAndSetXFromResponse(String response, XListListenerConfig config) {
			StringBuilder toParse = new StringBuilder(response);
			synchronized (_data) {
				do {
					String item = substringAndDeleteFromResponse(toParse, config._searchString,
							config._terminator);
					if (item != null) {
						addKnownX(item);
					} else {
						break;
					}
				} while (config._searchMultiple);
			}
		}
	}

	protected abstract static class XQueueListener<T> extends DataListener {
		private Queue<T> _data;

		protected XQueueListener(Queue<T> data) {
			_data = data;
		}

		protected void addKnownX(String value) {
			synchronized (_data) {
				if (validateValue(value)) {
					_data.add(convertStringToT(value));
				}
			}
		}

		protected void addX(T value) {
			synchronized (_data) {
				_data.add(value);
			}
		}

		/* Needs to deal with null */
		protected abstract T convertStringToT(String value);

		protected abstract boolean validateValue(String value);

		protected void findAndSetXFromResponse(String response, XListListenerConfig config) {
			StringBuilder toParse = new StringBuilder(response);
			synchronized (_data) {
				do {
					String item = substringAndDeleteFromResponse(toParse, config._searchString,
							config._terminator);
					if (item != null) {
						addKnownX(item);
					} else {
						break;
					}
				} while (config._searchMultiple);
			}
		}
	}
	
	protected abstract static class XResponseHolderListener<T, U> extends DataListener {
		protected ResponseHolder<T, U> _data;

		protected XResponseHolderListener(ResponseHolder<T, U> data) {
			_data = data;
		}

		public void handleResponse(T rawResponse) {
			synchronized (_data) {
				_data.setRawResponse(rawResponse);
				_data.setParsedResponse(null);
			}
		}

	}

	protected abstract static class XHolderListener<T> extends DataListener {
		protected Holder<T> _data;

		protected XHolderListener(Holder<T> data) {
			_data = data;
		}

		protected void addKnownX(String value) {
			synchronized (_data) {
				if (validateValue(value)) {
					_data.set(convertStringToT(value));
				}
			}
		}

		protected void addX(T value) {
			synchronized (_data) {
				_data.set(value);
			}
		}

		protected void clear() {
			_data.clear();
		}

		/* Needs to deal with null */
		protected abstract T convertStringToT(String value);

		protected abstract boolean validateValue(String value);

		protected void findAndSetXFromResponse(String response, XListListenerConfig config) {
			StringBuilder toParse = new StringBuilder(response);
			String item = substringAndDeleteFromResponse(toParse, config._searchString,
					config._terminator);
			if (item != null) {
				addKnownX(item);
			}
		}
	}

	protected abstract static class XMapListener<T> extends DataListener {
		private Map<String, T> _data;

		protected XMapListener(Map<String, T> data) {
			_data = data;
		}

		/*
		 * If the key already exists and there is a non-null value provided, it
		 * is replaced
		 */
		protected void addKnownX(String key, String value) {
			synchronized (_data) {
				if (validateValue(value)) {
					if (_data.containsKey(key) && (value != null)) {
						_data.remove(key);
					}
					_data.put(key, convertStringToT(value));
				}
			}
		}

		/* Needs to deal with null */
		protected abstract T convertStringToT(String value);

		/* Needs to deal with null */
		protected abstract boolean validateValue(String value);

		protected void findAndSetKeyValueFromResponse(String response, XMapListenerConfig config) {
			/* Copy the stringbuilder as we delete from it as we go */
			StringBuilder toParse = new StringBuilder(response);
			synchronized (_data) {
				do {
					String key, value;
					if (config._keyPrecedesValue) {
						key = substringAndDeleteFromResponse(toParse, config._keySearchString,
								config._keyTerminator);
						value = substringAndDeleteFromResponse(toParse, config._valueSearchString,
								config._valueTerminator);
					} else {
						value = substringAndDeleteFromResponse(toParse, config._valueSearchString,
								config._valueTerminator);
						key = substringAndDeleteFromResponse(toParse, config._keySearchString,
								config._keyTerminator);
					}
					if ((key != null) && (value != null)) {
						addKnownX(key, value);
					} else {
						break;
					}
				} while (config._searchMultiple);
			}
		}

		protected void findAndSetKeyFromResponse(String response, XListListenerConfig config) {
			StringBuilder toParse = new StringBuilder(response);
			synchronized (_data) {
				do {
					String key = substringAndDeleteFromResponse(toParse, config._searchString,
							config._terminator);
					if (key != null) {
						addKnownX(key, null);
					} else {
						break;
					}
				} while (config._searchMultiple);
			}
		}
	}

	protected abstract static class XMapIntegerListener extends XMapListener<Integer> {
		XMapIntegerListener(Map<String, Integer> data) {
			super(data);
		}

		@Override
		public Integer convertStringToT(String value) {
			if (value == null) {
				return null;
			} else {
				return Integer.parseInt(value);
			}
		}

		@Override
		public boolean validateValue(String value) {
			return true;
		}
	}

	protected abstract static class XMapStringListener extends XMapListener<String> {
		XMapStringListener(Map<String, String> data) {
			super(data);
		}

		@Override
		public String convertStringToT(String value) {
			if (value == null) {
				return null;
			} else {
				return value;
			}
		}

		@Override
		public boolean validateValue(String value) {
			return true;
		}
	}

	/**
	 * This is a listener for data which is returned in a response that is a
	 * JSON array. Each entry in the array is a piece of the data we are
	 * listening for. The terminators from the XMapListenerConfig are not used.
	 * 
	 * @author hrosenbe
	 * 
	 */
	protected abstract static class XMapStringJsonListener extends XMapStringListener {
		XMapStringJsonListener(Map<String, String> data) {
			super(data);
		}

		@Override
		public boolean validateValue(String value) {
			return true;
		}

		private String getStringValueFromJson(JSONObject inJsonObject, String key) {
			// System.out.println("XMapStringJsonListener::getStringValueFromJson key="
			// + key);
			String value = null;
			StringTokenizer keyTokenizer = new StringTokenizer(key, ".");

			try {
				JSONObject jsonObject = new JSONObject(inJsonObject.toString());
				// Go into the JSON object to get the embedded object with the
				// key/value we want
				while (keyTokenizer.countTokens() > 1) {
					jsonObject = jsonObject.getJSONObject(keyTokenizer.nextToken());
				}

				value = jsonObject.getString(keyTokenizer.nextToken());
			} catch (JSONException ex) {
				System.out
						.println("XMapStringJsonListener::getStringValueFromJson. JSONException when getting key="
								+ key
								+ " from jsonobject="
								+ inJsonObject.toString()
								+ "\n\tException message = " + ex.getMessage());
				throw new RuntimeException(ex);
			}

			return value;
		}

		@Override
		protected void findAndSetKeyValueFromResponse(String response, XMapListenerConfig config) {
			JSONObject toParse = null;
			JSONArray toParseArray = null;

			// Need to determine whether the returned JSON object is a JSONarray
			// or a single JSONobject. If it is a single object, then we only
			// get one value returned in the response.
			boolean isJsonArray = true;
			if (response.charAt(0) != '[') {
				isJsonArray = false;
			}
			String key = null, value = null;
			try {
				if (isJsonArray) {
					// System.out.println("\tXMapStringJsonListener::findAndSetKeyValueFromResponse Response is a JSONArray");
					toParseArray = new JSONArray(response);

					for (int i = 0; i < toParseArray.length(); i++) {
						key = getStringValueFromJson(toParseArray.getJSONObject(i),
								config._keySearchString);
						value = getStringValueFromJson(toParseArray.getJSONObject(i),
								config._valueSearchString);
						if ((key != null) && (value != null)) {
							// System.out.println("\tXMapStringJsonListener::findAndSetKeyValueFromResponse Adding key="
							// + key + " value=" + value);
							addKnownX(key, value);
						}
					}
				} else {
					// System.out.println("\tXMapStringJsonListener::findAndSetKeyValueFromResponse Response is not a JSONArray");
					toParse = new JSONObject(response);
					key = getStringValueFromJson(toParse, config._keySearchString);
					value = getStringValueFromJson(toParse, config._valueSearchString);
					if ((key != null) && (value != null)) {
						// System.out.println("\tXMapStringJsonListener::findAndSetKeyValueFromResponse Adding key="
						// + key + " value=" + value);
						addKnownX(key, value);
					}
				}
			} catch (JSONException ex) {
				System.out
						.print("XMapStringJsonListener::findAndSetKeyValueFromResponse. JSONException isArray="
								+ isJsonArray);
				System.out.println(" response=" + response + " when key=" + key + " and value="
						+ value + "\n\tException message = " + ex.getMessage());
				throw new RuntimeException(ex);
			}

		}

		@Override
		protected void findAndSetKeyFromResponse(String response, XListListenerConfig config) {
			JSONObject toParse = null;
			JSONArray toParseArray = null;
			// System.out.println("XMapStringJsonListener::findAndSetKeyFromResponse ");
			// Need to determine whether the returned JSON object is a JSONarray
			// or a single JSONobject. If it is a single object, then we only
			// get one value returned in the response.
			boolean isJsonArray = true;
			if (response.charAt(0) != '[') {
				isJsonArray = false;
			}

			String key = null;
			try {
				if (isJsonArray) {
					// System.out.println("\tXMapStringJsonListener::findAndSetKeyFromResponse Response is a JSONArray");
					toParseArray = new JSONArray(response);

					for (int i = 0; i < toParseArray.length(); i++) {
						key = getStringValueFromJson(toParseArray.getJSONObject(i),
								config._searchString);
						if (key != null) {
							// System.out.println("\tXMapStringJsonListener::findAndSetKeyFromResponse Adding key="
							// + key);
							addKnownX(key, null);
						}
					}
				} else {
					// System.out.println("\tXMapStringJsonListener::findAndSetKeyFromResponse Response is not a JSONArray");
					toParse = new JSONObject(response);

					key = getStringValueFromJson(toParse, config._searchString);
					if (key != null) {
						// System.out.println("\tXMapStringJsonListener::findAndSetKeyFromResponse Adding key="
						// + key);
						addKnownX(key, null);
					}
				}
			} catch (JSONException ex) {
				System.out
						.print("XMapStringJsonListener::findAndSetKeyFromResponse. JSONException isArray="
								+ isJsonArray);
				System.out.println(" response=" + response + " when key=" + key
						+ "\n\tException message = " + ex.getMessage());
				throw new RuntimeException(ex);

			}
		}
	}

	protected abstract static class XListStringListener extends XListListener<String> {
		protected XListStringListener(List<String> data) {
			super(data);
		}

		@Override
		public String convertStringToT(String value) {
			return value;
		}

		@Override
		public boolean validateValue(String value) {
			return true;
		}
	}

	public abstract static class XSetStringListener extends XSetListener<String> {
		protected XSetStringListener(Set<String> data) {
			super(data);
		}

		@Override
		public String convertStringToT(String value) {
			return value;
		}

		@Override
		public boolean validateValue(String value) {
			return true;
		}
	}

	protected abstract static class XHolderStringListener extends XHolderListener<String> {
		protected XHolderStringListener(Holder<String> data) {
			super(data);
		}

		@Override
		public String convertStringToT(String value) {
			return value;
		}

		@Override
		public boolean validateValue(String value) {
			return true;
		}
	}

	protected abstract static class XListJsonObjectListener extends XListListener<JSONObject> {
		protected XListJsonObjectListener(List<JSONObject> data) {
			super(data);
		}

		@Override
		public JSONObject convertStringToT(String value) {
			JSONObject convertedObject = null;
			try {
				convertedObject = new JSONObject(value);
			} catch (JSONException ex) {
				System.out.println("XListJsonObjectListener::ConvertStringToT exception value="
						+ value + " message: " + ex.getMessage());
				throw new RuntimeException(ex);
			}
			return convertedObject;
		}

		@Override
		public boolean validateValue(String value) {
			return true;
		}

		@Override
		protected void findAndSetXFromResponse(String response, XListListenerConfig config) {
			JSONArray toParseArray = null;
			// System.out.println("XListJsonObjectListener::findAndSetXFromResponse ");
			// Need to determine whether the returned JSON object is a JSONarray
			// or a single JSONobject. If it is a single object, then we only
			// get one value returned in the response.
			boolean isJsonArray = true;
			if (response.charAt(0) != '[') {
				isJsonArray = false;
			}

			try {
				if (isJsonArray) {
					// System.out.println("\tXListJsonObjectListener::findAndSetXFromResponse Response is a JSONArray");
					toParseArray = new JSONArray(response);

					for (int i = 0; i < toParseArray.length(); i++) {
						addKnownX(toParseArray.getJSONObject(i).toString());
					}
				} else {
					// System.out.println("\tXListJsonObjectListener::findAndSetXFromResponse Response is not a JSONArray");
					addKnownX(response);
				}
			} catch (JSONException ex) {
				System.out
						.println("XListJsonObjectListener::findAndSetXFromResponse. JSONException isJsonArray="
								+ isJsonArray
								+ " response="
								+ response
								+ "\n\tException message = " + ex.getMessage());
				throw new RuntimeException(ex);
			}
		}

	}

	protected abstract static class XHolderJsonObjectListener extends XHolderListener<JSONObject> {
		protected XHolderJsonObjectListener(Holder<JSONObject> data) {
			super(data);
		}

		@Override
		public JSONObject convertStringToT(String value) {
			JSONObject convertedObject = null;
			try {
				convertedObject = new JSONObject(value);
			} catch (JSONException ex) {
				System.out.println("XHolderJsonObjectListener::ConvertStringToT value=" + value
						+ " exception: " + ex.getMessage());
				throw new RuntimeException(ex);
			}
			return convertedObject;
		}

		@Override
		public boolean validateValue(String value) {
			return true;
		}

		@Override
		protected void findAndSetXFromResponse(String response, XListListenerConfig config) {
			// System.out.println("XHolderJsonObjectListener::findAndSetXFromResponse ");
			// Need to determine whether the returned JSON object is a JSONarray
			// or a single JSONobject. If it is a JSON array, then throw an
			// exception
			// as we should be using a list listener.
			boolean isJsonArray = true;
			if (response.charAt(0) != '[') {
				isJsonArray = false;
			}

			if (isJsonArray) {
				System.err
						.println("XHolderJsonObjectListener: Trying to create a Holder<JSONObject> from a JSONArray");
				throw new RuntimeException(
						"XHolderJsonObjectListener: Trying to create a Holder<JSONObject> from a JSONArray");
			}

			addKnownX(response);
		}

	}

	/*** PROVIDER BASE CLASSES ***/

	abstract public static class DataProvider {
	}

	protected abstract static class XListProvider<T> extends DataProvider {
		protected List<T> _data;
		private Random _random;

		protected XListProvider(List<T> data, Random random) {
			_data = data;
			_random = random;
		}

		@SuppressWarnings("unchecked")
		protected T getRandomXItem(String type) {
			synchronized (_data) {
				if (_data.size() > 0) {
					logger.debug("XListProvider:GetRandomXItem _data.size = " + _data.size());
					T[] xArray = (T[]) _data.toArray();
					return xArray[_random.nextInt(_data.size())];
				} else {
					throw new RuntimeException("ERROR: No known " + type + "s available to " + type
							+ "Provider!");
				}
			}
		}

		protected T getXItemAtIndex(int index, String type) {
			synchronized (_data) {
				if (_data.size() > 0) {
					return _data.get(index);
				} else {
					throw new RuntimeException("ERROR: No known " + type + "s available to " + type
							+ "Provider!");
				}
			}
		}

		public int size() {
			return _data.size();
		}

		protected T[] getAllKnownValues() {
			synchronized (_data) {
				return _data.toArray(getArrayTypeForT());
			}
		}

		public abstract T[] getArrayTypeForT();

	}

	protected abstract static class XSetProvider<T> extends DataProvider {
		protected Set<T> _data;
		protected Random _random;

		protected XSetProvider(Set<T> data, Random random) {
			_data = data;
			_random = random;
		}

		@SuppressWarnings("unchecked")
		protected T getRandomXItem(String type) {
			synchronized (_data) {
				if (_data.size() > 0) {
					T[] xArray = (T[]) _data.toArray();
					return xArray[_random.nextInt(_data.size())];
				} else {
					throw new RuntimeException("ERROR: No known " + type + "s available to " + type
							+ "Provider!");
				}
			}
		}

		public boolean contains(T item) {
			return _data.contains(item);
		}

		public T[] getAllKnownValues() {
			synchronized (_data) {
				return _data.toArray(getArrayTypeForT());
			}
		}

		public int size() {
			return _data.size();
		}

		public abstract T[] getArrayTypeForT();

	}

	protected abstract static class XQueueProvider<T> extends DataProvider {
		private Queue<T> _data;
		private Random _random;

		protected XQueueProvider(Queue<T> data, Random random) {
			_data = data;
			_random = random;
		}

		@SuppressWarnings("unchecked")
		protected T getRandomXItem(String type) {
			synchronized (_data) {
				if (_data.size() > 0) {
					T[] xArray = (T[]) _data.toArray();
					return xArray[_random.nextInt(_data.size())];
				} else {
					throw new RuntimeException("ERROR: No known " + type + "s available to " + type
							+ "Provider!");
				}
			}
		}

		public boolean contains(T item) {
			synchronized (_data) {
				return _data.contains(item);
			}
		}

		public boolean remove(T item) {
			synchronized (_data) {
				return _data.remove(item);
			}
		}

		public boolean isEmpty() {
			synchronized (_data) {
				return _data.isEmpty();
			}
		}

		public int size() {
			return _data.size();
		}

		public T[] getAllKnownValues() {
			synchronized (_data) {
				return _data.toArray(getArrayTypeForT());
			}
		}

		public abstract T[] getArrayTypeForT();

	}

	public abstract static class XResponseHolderProvider<T, U> extends DataProvider {
		protected ResponseHolder<T, U> _data;

		public XResponseHolderProvider(ResponseHolder<T, U> data) {
			_data = data;
		}

		public T getRawResponse() {
			if (_data != null) {
				synchronized (_data) {
					if (_data.getRawResponse() != null) {
						return _data.getRawResponse();
					} else {
						throw new IllegalStateException("ERROR: No rawResponse in  " + this.getClass().getCanonicalName());
					}
				}
			} else {
				throw new IllegalStateException("ERROR: data is null in  " + this.getClass().getCanonicalName());
			}
		}


		public U getResponse() {
			U parsedResponse = null;
			if (_data != null) {
				synchronized (_data) {
					if (_data.getParsedResponse() != null) {
						parsedResponse = _data.getParsedResponse();
					} else {
						parsedResponse = parseResponse();
						_data.setParsedResponse(parsedResponse);
						_data.setRawResponse(null);
					}
				}
			} else {
				throw new IllegalStateException("ERROR: data is null in  " + this.getClass().getCanonicalName());
			}
			return parsedResponse;
		}
		
		protected abstract U parseResponse();
	}

	public static class XHolderProvider<T> extends DataProvider {
		protected Holder<T> _data;

		public XHolderProvider(Holder<T> data) {
			// System.out.println("XHolderProvider constructor : _data = " +
			// _data);
			_data = data;
		}

		public T getItem(String type) {
			if (_data != null) {
				synchronized (_data) {
					if (_data.get() != null) {
						return _data.get();
					} else {
						throw new IllegalStateException("ERROR: No known " + type
								+ " available to " + type + "Provider!");
					}
				}
			} else {
				throw new IllegalStateException("ERROR: data is null for " + type + "Provider!");
			}
		}
	}

	protected abstract static class XStringMapProvider<T> extends DataProvider {
		private Map<String, T> _data;
		private Random _random;

		protected XStringMapProvider(Map<String, T> data, Random random) {
			_data = data;
			_random = random;
		}

		protected String getRandomXKey(boolean mustHaveValue, String type) {
			synchronized (_data) {
				Map<String, T> toPickFrom = _data;
				if (mustHaveValue) {
					toPickFrom = new HashMap<String, T>();
					for (String key : _data.keySet()) {
						T value = _data.get(key);
						if (value != null) {
							toPickFrom.put(key, value);
						}
					}
				}
				if (toPickFrom.size() > 0) {
					String[] xArray = toPickFrom.keySet().toArray(new String[] {});
					return xArray[_random.nextInt(toPickFrom.size())];
				} else {
					throw new RuntimeException("ERROR: No known " + type + "s available to " + type
							+ "Provider!");
				}
			}
		}

		public int size() {
			return _data.size();
		}

		protected T getValueForKey(String key, String type1, String type2) {
			synchronized (_data) {
				T value = _data.get(key);
				if (value == null) {
					throw new RuntimeException("ERROR: No " + type1 + " for " + type2
							+ " in Provider!");
				}
				return value;
			}
		}

		public T[] getAllKnownValues() {
			synchronized (_data) {
				return _data.values().toArray(getArrayTypeForT());
			}
		}

		public T[] getAllKnownKeys() {
			synchronized (_data) {
				return _data.keySet().toArray(getArrayTypeForT());
			}
		}

		public abstract T[] getArrayTypeForT();
	}

	protected abstract static class XMapProvider<X, T> extends DataProvider {
		protected Map<X, T> _data;
		private Random _random;

		protected XMapProvider(Map<X, T> data, Random random) {
			_data = data;
			_random = random;
		}

		protected String getRandomXKey(boolean mustHaveValue, String type) {
			synchronized (_data) {
				Map<X, T> toPickFrom = _data;
				if (mustHaveValue) {
					toPickFrom = new HashMap<X, T>();
					for (X key : _data.keySet()) {
						T value = _data.get(key);
						if (value != null) {
							toPickFrom.put(key, value);
						}
					}
				}
				if (toPickFrom.size() > 0) {
					String[] xArray = toPickFrom.keySet().toArray(new String[] {});
					return xArray[_random.nextInt(toPickFrom.size())];
				} else {
					throw new RuntimeException("ERROR: No known " + type + "s available to " + type
							+ "Provider!");
				}
			}
		}

		public T getValueForKey(X key, String type1, String type2) {
			synchronized (_data) {
				T value = _data.get(key);
				if (value == null) {
					throw new RuntimeException("ERROR: No " + type1 + " for " + type2
							+ " in Provider! Key = " + key);
				}
				return value;
			}
		}

		public int size() {
			return _data.size();
		}

		public X[] getAllKnownKeys() {
			synchronized (_data) {
				return _data.keySet().toArray(getArrayTypeForX());
			}
		}

		public T[] getAllKnownValues() {
			synchronized (_data) {
				return _data.values().toArray(getArrayTypeForT());
			}
		}

		public abstract X[] getArrayTypeForX();

		public abstract T[] getArrayTypeForT();
	}

	/*** PROVIDER BASE CLASSES ***/

	protected abstract static class XMapIntegerProvider extends XStringMapProvider<Integer> {

		protected XMapIntegerProvider(Map<String, Integer> data, Random random) {
			super(data, random);
		}

		@Override
		public Integer[] getArrayTypeForT() {
			return new Integer[] {};
		}
	}

	protected abstract static class XMapUUIDHolderJSONObjectProvider extends
			XMapProvider<UUID, Holder<JSONObject>> {

		protected XMapUUIDHolderJSONObjectProvider(Map<UUID, Holder<JSONObject>> data, Random random) {
			super(data, random);
		}

		@Override
		public UUID[] getArrayTypeForX() {
			return new UUID[] {};
		}

		@Override
		public Holder<JSONObject>[] getArrayTypeForT() {
			return (Holder<JSONObject>[]) Array.newInstance(Holder.class, 1);
		}
	}

	protected abstract static class XMapStringProvider extends XStringMapProvider<String> {

		protected XMapStringProvider(Map<String, String> data, Random random) {
			super(data, random);
		}

		@Override
		public String[] getArrayTypeForT() {
			return new String[] {};
		}
	}

	protected abstract static class XListStringProvider extends XListProvider<String> {

		protected XListStringProvider(List<String> data, Random random) {
			super(data, random);
		}

		public String getStringAtIndex(int index, String type) {
			return getXItemAtIndex(index, type);
		}

		@Override
		public String[] getArrayTypeForT() {
			return new String[] {};
		}
	}

	public abstract static class XSetStringProvider extends XSetProvider<String> {

		protected XSetStringProvider(Set<String> data, Random random) {
			super(data, random);
		}

		@Override
		public String[] getArrayTypeForT() {
			return new String[] {};
		}
	}

	protected abstract static class XQueueUUIDProvider extends XQueueProvider<UUID> {

		protected XQueueUUIDProvider(Queue<UUID> data, Random random) {
			super(data, random);
		}

		@Override
		public UUID[] getArrayTypeForT() {
			return new UUID[] {};
		}
	}

	protected abstract static class XHolderStringProvider extends XHolderProvider<String> {

		protected XHolderStringProvider(Holder<String> data) {
			super(data);
		}

		public String getString(String type) {
			return getItem(type);
		}

	}

	protected abstract static class XListJsonObjectProvider extends XListProvider<JSONObject> {

		protected XListJsonObjectProvider(List<JSONObject> data, Random random) {
			super(data, random);
		}

		public String getRandomValue(String key, String type) {
			JSONObject theObject = getRandomXItem(type);
			String theValue = null;
			try {
				theValue = theObject.getString(key);
			} catch (JSONException ex) {
				System.out.println("XListJsonObjectProvider::getRandomValue. JSONException key="
						+ key + " type=" + type + "\n\tException message = " + ex.getMessage());
				throw new RuntimeException(ex);
			}
			return theValue;
		}

		public String getValueAtIndex(int index, String key, String type) {
			JSONObject theObject = getXItemAtIndex(index, "type");
			String theValue = null;
			try {
				theValue = theObject.getString(key);
			} catch (JSONException ex) {
				System.out.println("XListJsonObjectProvider::getValueAtIndex. JSONException index="
						+ index + " key=" + key + " type=" + type + "\n\tException message = "
						+ ex.getMessage());
				throw new RuntimeException(ex);
			}
			return theValue;
		}

		public JSONObject[] getAllValues() {
			return getAllKnownValues();
		}

		@Override
		public JSONObject[] getArrayTypeForT() {
			return new JSONObject[] {};
		}

	}

	protected abstract static class XHolderJsonObjectProvider extends XHolderProvider<JSONObject> {

		protected XHolderJsonObjectProvider(Holder<JSONObject> data) {
			super(data);
		}

		public String getValue(String key, String type) {
			if (_data == null) {
				System.out.println("XHolderJsonObjectProvider:getValue _data == null, key = " + key
						+ ", type = " + type);
			}

			JSONObject theObject = getItem(type);
			String theValue = null;
			try {
				theValue = theObject.getString(key);
			} catch (JSONException ex) {
				System.out.println("XHolderJsonObjectProvider::getValue. JSONException key=" + key
						+ " type=" + type + "\n\tException message = " + ex.getMessage());
				throw new RuntimeException(ex);
			}
			return theValue;
		}

	}

}