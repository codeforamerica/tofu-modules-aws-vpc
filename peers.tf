resource "aws_vpc_peering_connection" "peer" {
  for_each = var.peers

  peer_owner_id = each.value.account_id
  peer_vpc_id   = each.value.vpc_id
  vpc_id        = module.vpc.vpc_id
  peer_region   = each.value.region

  tags = merge(var.tags, { Name = "${local.prefix}-${each.key}" })
}

resource "aws_route" "peer" {
  for_each = local.peer_routes

  route_table_id            = module.vpc.private_route_table_ids[each.value.table_index]
  destination_cidr_block    = each.value.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer[each.value.peer].id
}
