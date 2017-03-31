
<div>
	<h4><%= translate("editItem") %></h4>
	<form class="form-horizontal" role="form">
		<div id="editItem-name-control" class="form-group">
			<label for="editItem-name-input" class="control-label"> 
				<%= translate("itemName") %>: 
			</label>
				<input type="text" maxlength="255" id="editItem-name-input" class="form-control focused" value="<%= name %>">
		</div>
		<div id="editItem-manufacturer-control" class="form-group">
			<label for="editItem-manufacturer-input" class="control-label"> 
				<%= translate("itemManufacturer") %>: 
			</label>
				<input type="text" maxlength="100" id="editItem-manufacturer-input" class="form-control" value="<%= manufacturer%>">
		</div>
		<div id="editItem-longDescription-control" class="form-group">
			<label for="editItem-longDescription-input" class="control-label"> 
				<%= translate("description") %>: 
			</label>
				<textarea id="editItem-longDescription-input" maxlength="1024" class="form-control">
				</textarea>
		</div>
		<div id="editItem-startingBid-control" class="form-group">
			<label for="editItem-startingBid-input" class="control-label">
				<%= translate("startingBid") %>:
			</label>
				<input type="number" value="0" id="editItem-startingBid-input"
					class="form-control" value="<%= startingBidAmount %>">
		</div>
		<div id="editItem-dateOfOrigin-control" class="form-group">
			<label for="editItem-dateOfOrigin-input" class="control-label">
				<%= translate("dateOfOrigin") %>:
			</label>
				<input id="editItem-dateOfOrigin-input" type="text" data-date-format="mm/dd/yyyy" class="form-control datepicker" value="<%= dateOfOriginString %>">
		</div>
		<div id="editItem-condition-control" class="form-group">
			<label for="editItem-condition-input" class="control-label">
				<%= translate("condition") %>:
			</label>
				<select id="editItem-condition-input" class="form-control" >
					<option value="New"><%= translate("newCondition") %></option>
					<option value="Excellent"><%= translate("excellent") %></option>
					<option value="VeryGood"><%= translate("veryGood") %></option>
					<option value="Good"><%= translate("good") %></option>
					<option value="Fair"><%= translate("fair") %></option>
					<option value="Poor"><%= translate("poor") %></option>
					<option value="Bad"><%= translate("bad") %></option>
				</select>
		</div>
		<div id="editItem-addImage-control" class="form-group">
			<label for="editItem-addImage-input" class="control-label">
				<%= translate("addImages") %>:
			</label>
				<input id="editItem-addImage-input" type="file"multiple><br/>
				<div id="editItem-progress" class="progress">
					<div class="progress-bar progress-bar-success"></div>
				</div>
				<div id="editItem-files" class="files"></div>
		</div>
		
		<div class="form-actions">
			<button id="editItemBtn" class="btn btn-lg btn-primary"><%= translate("update") %></button>
		</div>
	</form>
</div>
