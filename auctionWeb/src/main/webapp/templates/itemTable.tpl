	<div class="title"><h4><%= translate("items") %></h4></div>
	<div id="itemTableDiv">
 	<table id="itemTable" class="table table-striped table-bordered table-condensed well show-well">
		<thead>
        	<tr>
           		<th><%= translate("item") %></th>
                <th><%= translate("itemName") %></th>
           	 	<th><%= translate("itemManufacturer") %></th>
               	<th><%= translate("auctionId") %></th>
               	<th><%= translate("itemState") %></th>
               	<th><%= translate("image") %></th>
               	<th><%= translate("itemDetail") %></th>
			</tr>
		</thead>
       	<tbody id="itemTableBody"></tbody>
	</table>
    <div class="pagination-container"/>
	</div>
    <div id="no-items"></div>
