import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../application/library_controller.dart';
import '../data/models/article.dart';

/// One article, from `GET /library/articles/{slug}`. The body is real HTML-free
/// text from the API (already localized); nothing about reading time, images or
/// author bio is invented.
class ArticleDetailsScreen extends ConsumerWidget {
  const ArticleDetailsScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(articleDetailProvider(slug));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          async.valueOrNull?.title ?? l.libraryTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () async => ref.invalidate(articleDetailProvider(slug)),
          ),
          data: (article) => _Body(article: article),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tag = Localizations.localeOf(context).toLanguageTag();
    final authorType = switch (article.author.type) {
      ArticleAuthorType.mamilyStaff => l.libraryAuthorStaff,
      ArticleAuthorType.specialist => l.libraryAuthorSpecialist,
      _ => null,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (article.categories.isNotEmpty)
          Text(
            article.categories.map((c) => c.name).join(' · '),
            style: const TextStyle(
              color: AppColors.coral,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        const SizedBox(height: 6),
        Text(
          article.title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if ((article.author.name ?? '').isNotEmpty)
              Text(
                article.author.name!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            if (authorType != null)
              Text(
                '· $authorType',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            if (article.publishedAt != null)
              Text(
                '· ${DateFormat.yMMMd(tag).format(article.publishedAt!.toLocal())}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (article.hasBody)
          Text(
            article.body!,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              height: 1.7,
            ),
          )
        else
          Text(
            article.excerpt ?? l.libraryNoBody,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.6,
            ),
          ),
      ],
    );
  }
}
