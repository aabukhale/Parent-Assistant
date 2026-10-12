import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/design_system.dart';
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
      appBar: AppBar(
        title: Text(
          async.valueOrNull?.title ?? l.libraryTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.type.titleSmall,
        ),
      ),
      body: AppContentFrame(
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        if (article.categories.isNotEmpty)
          Text(
            article.categories.map((c) => c.name).join(' · '),
            style: context.type.labelMedium?.copyWith(
              color: context.mamily.actionText,
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(article.title, style: context.type.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if ((article.author.name ?? '').isNotEmpty)
              Text(
                article.author.name!,
                style: context.type.bodySmall?.copyWith(
                  color: context.mamily.ink2,
                ),
              ),
            if (authorType != null)
              Text(
                '· $authorType',
                style: context.type.bodySmall?.copyWith(
                  color: context.mamily.ink2,
                ),
              ),
            if (article.publishedAt != null)
              Text(
                '· ${DateFormat.yMMMd(tag).format(article.publishedAt!.toLocal())}',
                style: context.type.bodySmall?.copyWith(
                  color: context.mamily.ink2,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (article.hasBody)
          Text(article.body!, style: context.type.bodyLarge)
        else
          Text(
            article.excerpt ?? l.libraryNoBody,
            style: context.type.bodyMedium?.copyWith(
              color: context.mamily.ink2,
            ),
          ),
      ],
    );
  }
}
