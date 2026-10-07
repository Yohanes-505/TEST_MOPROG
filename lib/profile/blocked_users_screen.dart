import 'package:bumble/constants/app_colors.dart';
import 'package:bumble/models/profile_model.dart';
import 'package:bumble/services/block_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<ProfileModel> _blocked = [];
  bool _isLoading = true;
  final Set<String> _busyIds = {};

  String? get _myId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final myId = _myId;
    if (myId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final profiles = await BlockService.getBlockedProfiles(myId);
    if (!mounted) return;
    setState(() {
      _blocked = profiles;
      _isLoading = false;
    });
  }

  Future<void> _unblock(ProfileModel profile) async {
    final myId = _myId;
    if (myId == null || _busyIds.contains(profile.id)) return;

    setState(() => _busyIds.add(profile.id));

    final success = await BlockService.unblockUser(
      blockerId: myId,
      blockedId: profile.id,
    );

    if (!mounted) return;
    setState(() => _busyIds.remove(profile.id));

    if (success) {
      setState(() => _blocked.removeWhere((p) => p.id == profile.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${profile.name} sudah di-unblock')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal unblock, coba lagi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akun yang Diblokir'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _blocked.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        Icon(Icons.block, size: 48, color: AppColors.mist),
                        SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Belum ada akun yang kamu blokir.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _blocked.length,
                      itemBuilder: (context, index) {
                        final profile = _blocked[index];
                        final isBusy = _busyIds.contains(profile.id);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: (profile.photoUrl != null &&
                                    profile.photoUrl!.startsWith('http'))
                                ? NetworkImage(profile.photoUrl!)
                                : null,
                            child: (profile.photoUrl == null ||
                                    !profile.photoUrl!.startsWith('http'))
                                ? const Icon(Icons.person, color: Colors.grey)
                                : null,
                          ),
                          title: Text(profile.name),
                          subtitle: profile.age != null
                              ? Text('${profile.age} tahun')
                              : null,
                          trailing: TextButton(
                            onPressed: isBusy ? null : () => _unblock(profile),
                            child: isBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Unblock'),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}