    <td><%= id %></td>
    <td><%= name %></td>
    <td><%= manufacturer %></td>
    <td><%= translate("item" + state) %></td>
    <td><%= auctionId %></td>
    <td><%= auction.utils.printCurrency(purchasePrice) %></td>
    <td><a class="itemDetail label label-info"><%= translate("details") %></a></td>
    <td><a class="editItem label label-info"><%= translate("edit") %></a></td>
    <td class="itemImage"></td>
    