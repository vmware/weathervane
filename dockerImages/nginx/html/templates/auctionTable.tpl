<div class="col-lg-12">
	<div class="title"><h4><%= translate("auctions") %></h4></div>
	<div id="auctionTableDiv" class = "">
 	<table id="auctionTable" class="table table-striped table-bordered table-condensed well show-well">
		<thead>
        	<tr>
           		<th><%= translate("auctionId") %></th>
                <th><%= translate("auctionName") %></th>
           	 	<th><%= translate("startDate") %></th>
               	<th><%= translate("startTime") %></th>
               	<th><%= translate("auctionCategory") %></th>
               	<th><%= translate("auctionState") %></th>
               	<th><%= translate("viewAuctionDetails") %></th>
			</tr>
		</thead>
       	<tbody id="auctionTableBody"></tbody>
	</table>
	</div>
    <div id="no-auctions"></div>
    <div class="pagination-container"/>
</div>