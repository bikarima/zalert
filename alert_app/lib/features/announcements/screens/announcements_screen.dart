import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/models/announcement_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<AnnouncementModel> _announcements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final readIds = await StorageService.instance.getReadAnnouncementIds();
      final raw     = await ApiService.instance.getAnnouncements();
      final list    = raw.map((j) => AnnouncementModel.fromJson(j)).toList();

      // mark read ones
      for (final a in list) {
        if (readIds.contains(a.id)) a.isRead = true;
      }

      // sort: unread first, then by date desc
      list.sort((a, b) {
        if (a.isRead != b.isRead) return a.isRead ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });

      setState(() {
        _announcements = list;
        _loading       = false;
      });
    } catch (e) {
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markRead(AnnouncementModel announcement) async {
    if (announcement.isRead) return;
    await StorageService.instance.markAnnouncementRead(announcement.id);
    setState(() => announcement.isRead = true);
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'warning': return AppTheme.red;
      case 'update':  return AppTheme.green;
      default:        return AppTheme.primary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'warning': return Icons.warning_amber_rounded;
      case 'update':  return Icons.system_update_alt_rounded;
      default:        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang  = context.watch<LocaleProvider>().lang;
    final isRtl = lang == 'fa';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.bg(context),
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_rounded,
                    size: 18.sp, color: AppTheme.text(context)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                lang == 'fa' ? 'اطلاعیه‌ها' : 'Announcements',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                    color: AppTheme.text(context)),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      size: 20.sp, color: AppTheme.text(context)),
                  onPressed: _loadAnnouncements,
                ),
              ],
            ),

            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 48.sp, color: AppTheme.textSec(context)),
                      SizedBox(height: 12.h),
                      Text(
                        lang == 'fa'
                            ? 'خطا در دریافت اطلاعیه‌ها'
                            : 'Failed to load announcements',
                        style: TextStyle(
                            color: AppTheme.textSec(context), fontSize: 14.sp),
                      ),
                      SizedBox(height: 12.h),
                      ElevatedButton(
                        onPressed: _loadAnnouncements,
                        child: Text(lang == 'fa' ? 'تلاش مجدد' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_announcements.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 56.sp, color: AppTheme.textSec(context)),
                      SizedBox(height: 12.h),
                      Text(
                        lang == 'fa'
                            ? 'هیچ اطلاعیه‌ای وجود ندارد'
                            : 'No announcements yet',
                        style: TextStyle(
                            color: AppTheme.textSec(context), fontSize: 14.sp),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final a = _announcements[i];
                    final color = _typeColor(a.type);
                    final icon  = _typeIcon(a.type);
                    return GestureDetector(
                      onTap: () => _markRead(a),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 5.h),
                        child: AnimatedContainer(
                          duration: 300.ms,
                          decoration: BoxDecoration(
                            color: AppTheme.card(context),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: a.isRead
                                  ? AppTheme.border(context)
                                  : color.withOpacity(0.4),
                              width: a.isRead ? 1 : 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(14.w),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // آیکون نوع
                                Container(
                                  width: 40.w, height: 40.w,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Icon(icon,
                                      color: color, size: 20.sp),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              a.title,
                                              style: TextStyle(
                                                color: AppTheme.text(context),
                                                fontSize: 13.sp,
                                                fontWeight: a.isRead
                                                    ? FontWeight.normal
                                                    : FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (!a.isRead)
                                            Container(
                                              width: 8.w, height: 8.w,
                                              decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        a.body,
                                        style: TextStyle(
                                          color: AppTheme.textSec(context),
                                          fontSize: 12.sp,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        _formatDate(a.createdAt),
                                        style: TextStyle(
                                          color: AppTheme.textSec(context),
                                          fontSize: 10.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(
                          duration: 300.ms,
                          delay: Duration(milliseconds: i * 50)),
                    );
                  },
                  childCount: _announcements.length,
                ),
              ),

            SliverToBoxAdapter(child: SizedBox(height: 32.h)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
