import React, { useState } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, TextInput } from 'react-native';
import { useTranslation } from '../context/LanguageContext';
import { useThemeColors } from '../context/ThemeContext';
import { useDatabase } from '../context/DatabaseContext';
import { Header } from '../components/Header';
import { Card } from '../components/Card';
import { MaterialIcons } from '@expo/vector-icons';

export const NotesListScreen = ({ navigation }) => {
  const { t, isRTL } = useTranslation();
  const { colors } = useThemeColors();
  const { notes } = useDatabase();
  const [searchQuery, setSearchQuery] = useState('');

  const filteredNotes = notes.filter(
    (note) =>
      note.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      note.courseName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      note.content.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const renderNoteItem = ({ item }) => {
    const formattedDate = new Date(item.createdAt).toLocaleDateString([], {
      month: 'short',
      day: 'numeric',
    });

    return (
      <Card
        onPress={() => navigation.navigate('NoteEditorScreen', { noteId: item.id })}
        style={styles.noteCard}
      >
        <View style={[styles.cardHeader, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
          <Text style={[styles.noteTitle, { color: colors.text }]} numberOfLines={1}>
            {item.title}
          </Text>
          {item.isAiFormatted && (
            <View style={[styles.aiBadge, { backgroundColor: colors.badgeBg }]}>
              <Text style={[styles.aiBadgeText, { color: colors.badgeText }]}>AI</Text>
            </View>
          )}
        </View>

        <Text style={[styles.noteContent, { color: colors.subtext, textAlign: isRTL ? 'right' : 'left' }]} numberOfLines={3}>
          {item.content}
        </Text>

        <View style={[styles.cardFooter, { flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
          <View style={[styles.courseTag, { backgroundColor: colors.border }]}>
            <Text style={[styles.courseText, { color: colors.text }]}>{item.courseName}</Text>
          </View>
          <Text style={[styles.dateText, { color: colors.subtext }]}>{formattedDate}</Text>
        </View>
      </Card>
    );
  };

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <Header title={t('notes_title')} />

      {/* Search Bar */}
      <View style={[styles.searchBarContainer, { backgroundColor: colors.card, borderBottomColor: colors.border, flexDirection: isRTL ? 'row-reverse' : 'row' }]}>
        <MaterialIcons name="search" size={20} color={colors.subtext} />
        <TextInput
          value={searchQuery}
          onChangeText={setSearchQuery}
          placeholder="گەڕان لە تێبینییەکان..."
          placeholderTextColor={colors.subtext}
          style={[styles.searchInput, { color: colors.text, textAlign: isRTL ? 'right' : 'left' }]}
        />
        {searchQuery.length > 0 && (
          <TouchableOpacity onPress={() => setSearchQuery('')}>
            <MaterialIcons name="close" size={20} color={colors.subtext} />
          </TouchableOpacity>
        )}
      </View>

      {filteredNotes.length === 0 ? (
        <View style={styles.emptyContainer}>
          <MaterialIcons name="note-add" size={60} color={colors.border} />
          <Text style={[styles.emptyTitle, { color: colors.text }]}>{t('no_notes_yet')}</Text>
          <Text style={[styles.emptyDesc, { color: colors.subtext }]}>{t('no_notes_desc')}</Text>
        </View>
      ) : (
        <FlatList
          data={filteredNotes}
          renderItem={renderNoteItem}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
        />
      )}

      {/* Fab Button */}
      <TouchableOpacity
        activeOpacity={0.8}
        onPress={() => navigation.navigate('NoteEditorScreen')}
        style={[styles.fab, { backgroundColor: colors.primary }]}
      >
        <MaterialIcons name="add" size={28} color="#FFFFFF" />
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  searchBarContainer: {
    height: 52,
    borderBottomWidth: 1,
    paddingHorizontal: 16,
    alignItems: 'center',
  },
  searchInput: {
    flex: 1,
    fontFamily: 'Noto Sans Arabic',
    fontSize: 14,
    marginHorizontal: 8,
    height: '100%',
  },
  listContent: {
    padding: 16,
    paddingBottom: 88,
  },
  noteCard: {
    marginVertical: 6,
  },
  cardHeader: {
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  noteTitle: {
    fontSize: 15,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    flex: 1,
  },
  aiBadge: {
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
    marginHorizontal: 8,
  },
  aiBadgeText: {
    fontSize: 10,
    fontWeight: 'bold',
  },
  noteContent: {
    fontSize: 13,
    fontFamily: 'Noto Sans Arabic',
    lineHeight: 18,
    marginBottom: 12,
  },
  cardFooter: {
    justifyContent: 'space-between',
    alignItems: 'center',
    borderTopWidth: 1,
    borderTopColor: 'rgba(0,0,0,0.03)',
    paddingTop: 8,
  },
  courseTag: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
  },
  courseText: {
    fontSize: 11,
    fontFamily: 'Noto Sans Arabic',
  },
  dateText: {
    fontSize: 11,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    fontFamily: 'Noto Sans Arabic',
    marginTop: 16,
  },
  emptyDesc: {
    fontSize: 13,
    fontFamily: 'Noto Sans Arabic',
    textAlign: 'center',
    marginTop: 8,
  },
  fab: {
    position: 'absolute',
    right: 16,
    bottom: 16,
    width: 56,
    height: 56,
    borderRadius: 28,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 6,
    elevation: 5,
  },
});
