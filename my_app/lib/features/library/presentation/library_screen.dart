import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/state_views.dart';
import '../../children/application/selected_child_controller.dart';
import '../application/library_controller.dart';
import '../data/models/article.dart';
import 'article_details_screen.dart';

/// The parent library. Replaces Anwar's hardcoded article list. Real articles
/// from `GET /library/articles` with a category filter (`GET /library/categories`)
/// and, when a child is selected, an age/interest recommendation strip
/// (`GET /library/recommendations?child_id=`).
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(articlesControllerProvider);
    final controller = ref.read(articlesControllerProvider.notifier);
    final hasChild = ref.watch(selectedChildProvider) != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l.libraryTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(libraryCategoriesProvider);
            ref.invalidate(libraryRecommendationsProvider);
            await controller.refresh();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              const _CategoryChips(),
              if (hasChild) ...[
                const SizedBox(height: 8),
                const _Recommendations(),
              ],
              const SizedBox(height: 12),
              async.when(
                skipLoadingOnReload: true,
                loading: () => const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  ),
                ),
                error: (e, _) =>
                    ErrorRetryView(error: e, onRetry: controller.refresh),
                data: (state) => state.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            l.libraryEmpty,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final article in state.articles)
                            _ArticleCard(article: article),
                          if (state.hasMore)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: state.loadingMore
                                  ? const CircularProgressIndicator(
                                      color: AppColors.coral,
                                    )
                                  : OutlinedButton(
                                      onPressed: () => _loadMore(context, ref),
                                      child: Text(l.libraryLoadMore),
                                    ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadMore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(articlesControllerProvider.notifier).loadMore();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.localizedMessage(context.l10n))));
    }
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final selected = ref.watch(libraryCategoryFilterProvider);
    final categories = ref.watch(libraryCategoriesProvider);

    return categories.maybeWhen(
      data: (cats) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: Text(l.libraryAllCategories),
              selected: selected == null,
              onSelected: (_) =>
                  ref.read(libraryCategoryFilterProvider.notifier).state = null,
            ),
            for (final cat in cats) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(cat.name),
                selected: selected == cat.key,
                onSelected: (_) =>
                    ref.read(libraryCategoryFilterProvider.notifier).state =
                        cat.key,
              ),
            ],
          ],
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Recommendations extends ConsumerWidget {
  const _Recommendations();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final recs = ref.watch(libraryRecommendationsProvider);

    return recs.maybeWhen(
      data: (articles) => articles.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Text(
                  l.libraryRecommendedTitle,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: articles.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final a = articles[i];
                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ArticleDetailsScreen(slug: a.slug),
                          ),
                        ),
                        child: Container(
                          width: 200,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              if (a.categories.isNotEmpty)
                                Text(
                                  a.categories.first.name,
                                  style: const TextStyle(
                                    color: Color(0xFFD8DDEC),
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ArticleDetailsScreen(slug: article.slug),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.categories.isNotEmpty)
              Text(
                article.categories.map((c) => c.name).join(' · '),
                style: const TextStyle(
                  color: AppColors.coral,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              article.title,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            if ((article.excerpt ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                article.excerpt!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
