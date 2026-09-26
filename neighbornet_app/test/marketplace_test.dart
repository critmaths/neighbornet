import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';
import 'package:neighbornet_app/views/marketplace_view.dart';

void main() {
  group('Barter & Marketplace Models and JSON serialization', () {
    test('BarterListing serialization and deserialization', () {
      final listing = BarterListing(
        id: 'list_123',
        authorHash: 'abc1234567890123',
        authorNickname: 'AliceTactical',
        title: '5 Gal Gasoline',
        description: 'Fresh stabilized gasoline in Jerry can',
        category: 'fuel',
        listingType: 'offer',
        seeking: 'Canned food or water filter',
        locationHint: 'Grid 42-A Rendezvous',
        urgency: 'high',
        status: 'open',
        timestampSec: 1700000000,
      );

      final json = listing.toJson();
      expect(json['id'], 'list_123');
      expect(json['title'], '5 Gal Gasoline');
      expect(json['category'], 'fuel');
      expect(json['listing_type'], 'offer');
      expect(json['seeking'], 'Canned food or water filter');

      final deserialized = BarterListing.fromJson(json);
      expect(deserialized.id, listing.id);
      expect(deserialized.authorNickname, 'AliceTactical');
      expect(deserialized.urgency, 'high');
      expect(deserialized.status, 'open');
    });

    test('BarterProposal serialization and deserialization', () {
      final proposal = BarterProposal(
        id: 'prop_999',
        listingId: 'list_123',
        proposerHash: 'def9876543210987',
        proposerNickname: 'BobRadio',
        offeredItems: '3x Freeze-dried meals + 1 Sawyer Squeeze filter',
        counterMessage: 'Can meet near water tower at sunset',
        status: 'pending',
        timestampSec: 1700001000,
      );

      final json = proposal.toJson();
      expect(json['id'], 'prop_999');
      expect(json['listing_id'], 'list_123');
      expect(json['offered_items'], contains('Freeze-dried'));

      final deserialized = BarterProposal.fromJson(json);
      expect(deserialized.id, proposal.id);
      expect(deserialized.proposerNickname, 'BobRadio');
      expect(deserialized.status, 'pending');
    });

    test('CommunityVouch serialization and deserialization', () {
      final vouch = CommunityVouch(
        id: 'vouch_777',
        voucherNodeHash: 'def9876543210987',
        voucherNickname: 'BobRadio',
        targetNodeHash: 'abc1234567890123',
        rating: 5,
        reviewComment: 'Prompt and honest trade of radio battery',
        timestampSec: 1700002000,
      );

      final json = vouch.toJson();
      expect(json['id'], 'vouch_777');
      expect(json['rating'], 5);
      expect(json['target_node_hash'], 'abc1234567890123');

      final deserialized = CommunityVouch.fromJson(json);
      expect(deserialized.id, vouch.id);
      expect(deserialized.rating, 5);
      expect(deserialized.reviewComment, contains('Prompt and honest'));
    });
  });

  group('MarketplaceView Widget Tests', () {
    testWidgets('MarketplaceView renders summary metrics, search bar, and empty state', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      final state = NeighborNetState();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: MarketplaceView(state: state),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mutual Aid & Barter Marketplace'), findsOneWidget);
      expect(find.text('Active Offers'), findsOneWidget);
      expect(find.text('Active Requests'), findsOneWidget);
      expect(find.text('Skills & Aid'), findsNWidgets(2));
      expect(find.text('Completed Trades'), findsOneWidget);
      expect(find.text('Post Listing'), findsOneWidget);
      expect(find.text('Search barter items, skills, authors...'), findsOneWidget);
      expect(find.text('All Categories'), findsOneWidget);

      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
