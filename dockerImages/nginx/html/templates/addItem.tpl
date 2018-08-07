
<div>
	<h4><%= translate("addItem") %></h4>
	<form class="form-horizontal" role="form">
		<div id="addItem-name-control" class="form-group">
			<label for="addItem-name-input" class="control-label"> 
				<%= translate("itemName") %>: 
			</label>
				<input type="text" maxlength="255" id="addItem-name-input" class="form-control focused">
		</div>
		<div id="addItem-manufacturer-control" class="form-group">
			<label for="addItem-manufacturer-input" class="control-label"> 
				<%= translate("itemManufacturer") %>: 
			</label>
				<input type="text" maxlength="100" id="addItem-manufacturer-input" class="form-control">
		</div>
		<div id="addItem-longDescription-control" class="form-group">
			<label for="addItem-longDescription-input" class="control-label"> 
				<%= translate("description") %>: 
			</label>
				<textarea id="addItem-longDescription-input" maxlength="1024" class="form-control">
				</textarea>
		</div>
		<div id="addItem-startingBid-control" class="form-group">
			<label for="addItem-startingBid-input" class="control-label">
				<%= translate("startingBid") %>:
			</label>
				<input type="number" value="0" id="addItem-startingBid-input"
					class="form-control">
		</div>
		<div id="addItem-dateOfOrigin-control" class="form-group">
			<label for="addItem-dateOfOrigin-input" class="control-label">
				<%= translate("dateOfOrigin") %>:
			</label>
				<input id="addItem-dateOfOrigin-input" type="text" data-date-format="mm/dd/yyyy" class="form-control datepicker">
		</div>
		<div id="addItem-condition-control" class="form-group">
			<label for="addItem-condition-input" class="control-label">
				<%= translate("condition") %>:
			</label>
				<select id="addItem-condition-input" class="form-control">
					<option value="New"><%= translate("newCondition") %></option>
					<option value="Excellent"><%= translate("excellent") %></option>
					<option value="VeryGood"><%= translate("veryGood") %></option>
					<option value="Good"><%= translate("good") %></option>
					<option value="Fair"><%= translate("fair") %></option>
					<option value="Poor"><%= translate("poor") %></option>
					<option value="Bad"><%= translate("bad") %></option>
				</select>
		</div>
		<div class="form-actions">
			<button id="addItemBtn" class="btn btn-lg btn-primary"><%= translate("add") %></button>
		</div>
	</form>
</div>
