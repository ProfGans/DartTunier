const minimumPlayersPerGroup = 3;

bool hasValidGroupSizes(List<int> sizes) =>
    sizes.isNotEmpty && sizes.every((size) => size >= minimumPlayersPerGroup);
