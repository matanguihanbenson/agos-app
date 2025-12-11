import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/color_palette.dart';
import '../theme/text_styles.dart';
import '../models/organization_model.dart';
import '../providers/organization_provider.dart';

class OrganizationAutocomplete extends ConsumerStatefulWidget {
  final String? selectedOrganizationId;
  final Function(String? organizationId, String? organizationName) onOrganizationSelected;
  final String? label;
  final String? hint;
  final bool isRequired;

  const OrganizationAutocomplete({
    super.key,
    this.selectedOrganizationId,
    required this.onOrganizationSelected,
    this.label,
    this.hint,
    this.isRequired = false,
  });

  @override
  ConsumerState<OrganizationAutocomplete> createState() => _OrganizationAutocompleteState();
}

class _OrganizationAutocompleteState extends ConsumerState<OrganizationAutocomplete> {
  final TextEditingController _searchController = TextEditingController();
  OrganizationModel? _selectedOrganization;
  bool _isExpanded = false;
  List<OrganizationModel> _filteredOrganizations = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(organizationProvider.notifier).loadOrganizations();
      _initializeSelectedOrganization();
    });
  }

  void _initializeSelectedOrganization() {
    if (widget.selectedOrganizationId != null) {
      final orgState = ref.read(organizationProvider);
      _selectedOrganization = orgState.organizations
          .where((org) => org.id == widget.selectedOrganizationId)
          .firstOrNull;
      if (_selectedOrganization != null) {
        _searchController.text = _selectedOrganization!.name;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterOrganizations(String query) {
    final orgState = ref.read(organizationProvider);
    setState(() {
      if (query.isEmpty) {
        _filteredOrganizations = orgState.organizations;
      } else {
        _filteredOrganizations = orgState.organizations
            .where((org) => org.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectOrganization(OrganizationModel org) {
    setState(() {
      _selectedOrganization = org;
      _searchController.text = org.name;
      _isExpanded = false;
    });
    widget.onOrganizationSelected(org.id, org.name);
  }

  Future<void> _createNewOrganization(String name) async {
    try {
      final orgId = await ref.read(organizationProvider.notifier).createOrganizationIfNotExists(name);
      
      if (orgId != null && mounted) {
        // Reload organizations to get the newly created one
        await ref.read(organizationProvider.notifier).loadOrganizations();
        
        final orgState = ref.read(organizationProvider);
        final newOrg = orgState.organizations.where((org) => org.id == orgId).firstOrNull;
        
        if (newOrg != null) {
          _selectOrganization(newOrg);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Organization "$name" created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create organization: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedOrganization = null;
      _searchController.clear();
      _isExpanded = false;
    });
    widget.onOrganizationSelected(null, null);
  }

  @override
  Widget build(BuildContext context) {
    final orgState = ref.watch(organizationProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  widget.label!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.isRequired)
                  Text(
                    ' *',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

        // Autocomplete Field
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isExpanded ? AppColors.primary : AppColors.border,
              width: _isExpanded ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              // Search Input
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.hint ?? 'Search or create organization...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                  prefixIcon: Icon(
                    Icons.business,
                    color: _isExpanded ? AppColors.primary : AppColors.textSecondary,
                  ),
                  suffixIcon: _selectedOrganization != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSelection,
                        )
                      : IconButton(
                          icon: Icon(
                            _isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          ),
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                              if (_isExpanded) {
                                _filterOrganizations(_searchController.text);
                              }
                            });
                          },
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) {
                  _filterOrganizations(value);
                  if (!_isExpanded) {
                    setState(() {
                      _isExpanded = true;
                    });
                  }
                },
                onTap: () {
                  setState(() {
                    _isExpanded = true;
                    _filterOrganizations(_searchController.text);
                  });
                },
              ),

              // Dropdown List
              if (_isExpanded) ...[
                const Divider(height: 1),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: orgState.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _filteredOrganizations.isEmpty && _searchController.text.isNotEmpty
                          ? _buildCreateNewOption()
                          : _filteredOrganizations.isEmpty
                              ? _buildEmptyState()
                              : _buildOrganizationList(),
                ),
              ],
            ],
          ),
        ),

        // Helper text for creating new org
        if (_isExpanded && _searchController.text.isNotEmpty && _filteredOrganizations.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Organization not found. You can create it by clicking above.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOrganizationList() {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _filteredOrganizations.length,
      itemBuilder: (context, index) {
        final org = _filteredOrganizations[index];
        final isSelected = _selectedOrganization?.id == org.id;

        return ListTile(
          dense: true,
          leading: Icon(
            Icons.business,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            size: 20,
          ),
          title: Text(
            org.name,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          subtitle: org.description.isNotEmpty
              ? Text(
                  org.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: isSelected
              ? Icon(Icons.check_circle, color: AppColors.primary, size: 20)
              : null,
          onTap: () => _selectOrganization(org),
        );
      },
    );
  }

  Widget _buildCreateNewOption() {
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.add_circle,
        color: AppColors.primary,
        size: 20,
      ),
      title: Text(
        'Create "${_searchController.text}"',
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      subtitle: Text(
        'Tap to create new organization',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textMuted,
        ),
      ),
      onTap: () => _createNewOrganization(_searchController.text.trim()),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 32, color: AppColors.textMuted),
            const SizedBox(height: 8),
            Text(
              'No organizations found',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start typing to create one',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
