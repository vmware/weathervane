	<div class="title"><h4><%= translate("myItems") %></h4></div>
	<div id="myItemsTableDiv">
	<div class="row">
		<div class="col-lg-2"><h5>Change search:</h5></div>
		<div class="col-lg-2">
			<button id="myItemsSearch" type="submit">Search</button>
		</div>
	</div>
	<table id="myItemsTable" class="table table-striped table-bordered table-condensed well show-well">
		<thead>
        	<tr>
                <th><%= translate("itemId") %></th>
                <th><%= translate("itemName") %></th>
           	 	<th><%= translate("itemManufacturer") %></th>
               	<th><%= translate("itemState") %></th>
               	<th><%= translate("auctionId") %></th>
               	<th><%= translate("purchasePrice") %></th>
           		<th><%= translate("itemDetail") %></th>
           		<th><%= translate("editItem") %></th>
           		<th><%= translate("image") %></th>
			</tr>
		</thead>
       	<tbody id="myItemsTableBody"></tbody>
	</table>
    <div class="pagination-container"/>
	</div>
