class TaskFilter {
  final String? selectedGroup;
  final int? selectedPriority;
  final String? selectedTag;

  TaskFilter({
    this.selectedGroup,
    this.selectedPriority,
    this.selectedTag,
  });

  TaskFilter copyWith({
    String? selectedGroup,
    int? selectedPriority,
    String? selectedTag,
  }) {
    return TaskFilter(
      selectedGroup: selectedGroup ?? this.selectedGroup,
      selectedPriority: selectedPriority ?? this.selectedPriority,
      selectedTag: selectedTag ?? this.selectedTag,
    );
  }

  bool get isEmpty {
    return selectedGroup == null && selectedPriority == null && selectedTag == null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskFilter &&
        other.selectedGroup == selectedGroup &&
        other.selectedPriority == selectedPriority &&
        other.selectedTag == selectedTag;
  }

  @override
  int get hashCode => Object.hash(selectedGroup, selectedPriority, selectedTag);
}