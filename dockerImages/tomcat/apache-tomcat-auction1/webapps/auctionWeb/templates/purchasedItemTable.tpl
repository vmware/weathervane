	<div class="title"><h4><%= translate("purchasedItems") %></h4></div>
	<div id="purchasedItemTableDiv">
	<div class="row">
		<div class="col-lg-2"><h5>Change search:</h5></div>
		<div class="col-lg-4">
			<label for="purchasedItemsFromDate"><%= translate("from") %>:</label> <input
				id="purchasedItemsFromDate" type="text"
				data-date-format="mm/dd/yyyy" class="datepicker">
		</div>
		<div class="col-lg-4">
			<label for="purchasedItemsToDate"><%= translate("to") %>:</label> <input
				id="purchasedItemsToDate" type="text"
				data-date-format="mm/dd/yyyy" class="datepicker">
		</div>
		<div class="col-lg-2">
			<button id="purchaseHistorySearch" type="submit">Search</button>
		</div>
	</div>
	<table id="purchasedItemTable" class="table table-striped table-bordered table-condensed well show-well">
		<thead>
        	<tr>
           		<th><%= translate("purchaseDate") %></th>
                <th><%= translate("itemName") %></th>
           	 	<th><%= translate("itemManufacturer") %></th>
               	<th><%= translate("purchasePrice") %></th>
               	<th><%= translate("itemState") %></th>
               	<th><%= translate("itemDetail") %></th>
               	<th><%= translate("image") %></th>
			</tr>
		</thead>
       	<tbody id="purchasedItemTableBody"></tbody>
	</table>
    <div class="pagination-container"/>
	</div>
