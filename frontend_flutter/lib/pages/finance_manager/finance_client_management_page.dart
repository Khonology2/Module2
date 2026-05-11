import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/client_service.dart';
import '../../theme/premium_theme.dart';

class FinanceClientManagementPage extends StatefulWidget {
  const FinanceClientManagementPage({super.key});

  @override
  State<FinanceClientManagementPage> createState() =>
      _FinanceClientManagementPageState();
}

class _FinanceClientManagementPageState
    extends State<FinanceClientManagementPage> {
  bool _loading = false;
  List<Map<String, dynamic>> _clients = [];
  final TextEditingController _searchController = TextEditingController();

  Future<void> _editClient(Map<String, dynamic> client) async {
    final id = client['id'];
    if (id == null) return;

    final nameController = TextEditingController(
        text: (client['company_name'] ?? client['name'] ?? '').toString());
    final emailController =
        TextEditingController(text: (client['email'] ?? '').toString());
    final holdingController = TextEditingController(
        text: (client['holding_information'] ?? '').toString());
    final addressController =
        TextEditingController(text: (client['address'] ?? '').toString());
    final contactNameController = TextEditingController(
        text: (client['contact_person'] ?? '').toString());
    final contactEmailController = TextEditingController(
        text: (client['client_contact_email'] ?? client['email'] ?? '')
            .toString());
    final contactMobileController = TextEditingController(
        text: (client['client_contact_mobile'] ?? client['phone'] ?? '')
            .toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Client'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Client Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Client Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: holdingController,
                  decoration:
                      const InputDecoration(labelText: 'Holding / Group'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: contactNameController,
                  decoration: const InputDecoration(labelText: 'Contact Name'),
                ),
                TextField(
                  controller: contactEmailController,
                  decoration: const InputDecoration(labelText: 'Contact Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: contactMobileController,
                  decoration:
                      const InputDecoration(labelText: 'Contact Mobile'),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final token = AuthService.token;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final result = await ClientService.updateClient(
        token: token,
        clientId: id is int ? id : int.tryParse(id.toString()) ?? 0,
        companyName: nameController.text.trim(),
        email: emailController.text.trim(),
        contactPerson: contactNameController.text.trim(),
        phone: contactMobileController.text.trim(),
        holdingInformation: holdingController.text.trim(),
        address: addressController.text.trim(),
        clientContactEmail: contactEmailController.text.trim(),
        clientContactMobile: contactMobileController.text.trim(),
      );

      final success = result != null && result['success'] == true;
      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update client')),
        );
        return;
      }

      await _loadClients();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteClient(Map<String, dynamic> client) async {
    final id = client['id'];
    if (id == null) return;

    final name =
        (client['company_name'] ?? client['name'] ?? '').toString().trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text(
          name.isNotEmpty
              ? 'Delete "$name"? This cannot be undone.'
              : 'Delete this client? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PremiumTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final token = AuthService.token;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final deleted = await ClientService.deleteClient(
        token: token,
        clientId: id is int ? id : int.tryParse(id.toString()) ?? 0,
      );
      if (!deleted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete client')),
        );
        return;
      }
      await _loadClients();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClients());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final token = AuthService.token;
      if (token == null) return;
      final clients = await ClientService.getClients(token);
      if (!mounted) return;
      setState(() {
        _clients = List<Map<String, dynamic>>.from(clients);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchController.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _clients
        : _clients.where((c) {
            final name =
                (c['company_name'] ?? c['name'] ?? '').toString().toLowerCase();
            final email = (c['email'] ?? '').toString().toLowerCase();
            final contact =
                (c['contact_person'] ?? '').toString().toLowerCase();
            return name.contains(q) || email.contains(q) || contact.contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 946.2045288461986,
                  decoration: BoxDecoration(
                    color: const Color(0x24FFFFFF),
                    borderRadius: BorderRadius.circular(5.32),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 3.55,
                        offset: Offset(0, 3.55),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/collaborations_red.png',
                              width: 73,
                              height: 73,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 460),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Clients Overview',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        letterSpacing: 0.2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Manage all your clients and their details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            SizedBox(
                              width: 245,
                              height: 43.060546875,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 22),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3D3D3D),
                                          borderRadius:
                                              BorderRadius.circular(22),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 36,
                                            right: 12,
                                          ),
                                          child: Center(
                                            child: TextField(
                                              controller: _searchController,
                                              style: const TextStyle(
                                                  color: Colors.white),
                                              decoration: const InputDecoration(
                                                hintText: 'Search Clients...',
                                                hintStyle: TextStyle(
                                                  color: Color(0xFF9CA3AF),
                                                  fontSize: 14,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                                isDense: true,
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 43,
                                    height: 43,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/images/new icons for manager/Search_Seek_Red Badge_White.png',
                                        width: 43,
                                        height: 43,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.pushNamed(
                                  context,
                                  '/finance/clients/add',
                                );
                                if (!mounted) return;
                                if (result == true) {
                                  await _loadClients();
                                }
                              },
                              icon: const Icon(Icons.add,
                                  size: 18, color: Colors.white),
                              label: const Text(
                                'New Client',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PremiumTheme.primaryRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Divider(
                          color: Colors.white.withOpacity(0.12),
                          height: 1,
                          thickness: 1,
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 330),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: _loading
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          PremiumTheme.primaryRed),
                                    ),
                                  ),
                                )
                              : _clients.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 48.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.people_alt_outlined,
                                              size: 64,
                                              color:
                                                  Colors.white.withOpacity(0.5),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'No clients yet',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Add your first client to get started',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : filtered.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 48.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.search_off_outlined,
                                                  size: 64,
                                                  color: Colors.white
                                                      .withOpacity(0.5),
                                                ),
                                                const SizedBox(height: 16),
                                                const Text(
                                                  'No clients match your search',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  'Try a different name or email',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: filtered.length,
                                          separatorBuilder: (_, __) => Divider(
                                            color:
                                                Colors.white.withOpacity(0.08),
                                            height: 20,
                                          ),
                                          itemBuilder: (context, index) {
                                            final c = filtered[index];
                                            final name = (c['company_name'] ??
                                                    c['name'] ??
                                                    '')
                                                .toString()
                                                .trim();
                                            final email = (c['email'] ?? '')
                                                .toString()
                                                .trim();
                                            final contact =
                                                (c['contact_person'] ?? '')
                                                    .toString()
                                                    .trim();

                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(
                                                name.isNotEmpty
                                                    ? name
                                                    : (email.isNotEmpty
                                                        ? email
                                                        : 'Client'),
                                                style: PremiumTheme.bodyLarge
                                                    .copyWith(
                                                        color: Colors.white),
                                              ),
                                              subtitle: Text(
                                                [
                                                  if (email.isNotEmpty) email,
                                                  if (contact.isNotEmpty)
                                                    contact,
                                                ].join(' • '),
                                                style: PremiumTheme.bodyMedium
                                                    .copyWith(
                                                        color: Colors.white70),
                                              ),
                                              trailing: PopupMenuButton<String>(
                                                color: const Color(0xFF111111),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                icon: const Icon(
                                                  Icons.more_vert,
                                                  color: Colors.white70,
                                                ),
                                                onSelected: (value) async {
                                                  if (value == 'edit') {
                                                    await _editClient(c);
                                                  } else if (value ==
                                                      'delete') {
                                                    await _deleteClient(c);
                                                  }
                                                },
                                                itemBuilder: (ctx) => const [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    textStyle: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    child: Text(
                                                      'Edit',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    textStyle: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    child: Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddClientCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final result =
            await Navigator.pushNamed(context, '/finance/clients/add');
        if (!mounted) return;
        if (result == true) {
          await _loadClients();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: PremiumTheme.darkBg2.withOpacity(0.85),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: PremiumTheme.tealGradient,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Client',
                    style: PremiumTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Enter a new client and make it available for managers',
                    style:
                        PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
