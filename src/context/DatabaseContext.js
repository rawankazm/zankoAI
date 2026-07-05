import React, { createContext, useContext, useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

const DatabaseContext = createContext();

export const DatabaseProvider = ({ children }) => {
  const [notes, setNotes] = useState([]);
  const [schedule, setSchedule] = useState([]);
  const [quizzes, setQuizzes] = useState([]);
  const [flashcards, setFlashcards] = useState([]);
  const [reminders, setReminders] = useState([]);
  const [stats, setStats] = useState({
    completedPomodoros: 1,
    quizzesTaken: 2,
    flashcardsFlipped: 4
  });
  const [isLoading, setIsLoading] = useState(true);

  // Initial Seed Data
  const initialNotes = [
    {
      id: 'n1',
      title: 'تێبینی دەربارەی سیستەمی کارپێکردن',
      content: 'سیستەمی کارپێکردن (OS) بریتییە لەو نەرمەکاڵایەی کە ڕەقەکاڵاکان و نەرمەکاڵاکانی تر بەڕێوەدەبات. کارە سەرەکییەکانی بریتین لە: بەڕێوەبردنی یادگە (Memory Management)، بەڕێوەبردنی پڕۆسسەکان (Process Management)، و سیستەمی فایلەکان (File System).',
      createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
      isAiFormatted: true,
      courseName: 'سیستەمی کارپێکردن',
    },
    {
      id: 'n2',
      title: 'کورتەی وانەی داتابەیس',
      content: 'داتابەیس (Database) سیستەمێکە بۆ کۆکردنەوە و ڕێکخستنی زانیارییەکان بە شێوازێک کە ئاسان بێت بۆ بەدەستهێنانەوە و دەستکاریکردن. جۆرە سەرەکییەکانی داتابەیس بریتین لە داتابەیسی پەیوەندیار (Relational DB) و داتابەیسی ناپەیوەندیار (NoSQL).',
      createdAt: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString(),
      isAiFormatted: false,
      courseName: 'بنکەی زانیاری',
    },
  ];

  const initialSchedule = [
    {
      id: 's1',
      courseName: 'سیستەمی کارپێکردن (OS)',
      time: '08:30 - 10:00',
      location: 'هۆڵی ٤، بەشی تەکنەلۆجیای زانیاری',
      dayName: 'شەممە',
      teacherName: 'د. ڕێبین ئەحمەد',
    },
    {
      id: 's2',
      courseName: 'بەرنامەسازی پێشکەوتوو (Dart & Flutter)',
      time: '10:15 - 11:45',
      location: 'لابۆراتۆری ٣، بەشی کۆمپیوتەر',
      dayName: 'شەممە',
      teacherName: 'م. شادان عومەر',
    },
    {
      id: 's3',
      courseName: 'بنکەی زانیاری',
      time: '08:30 - 10:00',
      location: 'هۆڵی ٢، بەشی تەکنەلۆجیای زانیاری',
      dayName: 'یەکشەممە',
      teacherName: 'م. هێمن مستەفا',
    },
    {
      id: 's4',
      courseName: 'پێداچوونەوەی پڕۆژەی دەرچوون',
      time: '12:00 - 13:30',
      location: 'هۆڵی فڕەنسی',
      dayName: 'دووشەممە',
      teacherName: 'د. ڕێبین ئەحمەد',
    },
  ];

  const initialQuizzes = [
    {
      id: 'q1',
      title: 'کویزی بنەماکانی کۆمپیوتەر',
      courseName: 'بنەماکانی کۆمپیوتەر',
      durationMinutes: 10,
      questions: [
        {
          id: 'q1_1',
          questionText: 'سی پی یو (CPU) مێشکی کۆمپیوتەرە و بەرپرسە لە پڕۆسێسکردنی فەرمانەکان.',
          type: 'trueFalse',
          correctAnswer: 'ڕاستە',
        },
        {
          id: 'q1_2',
          questionText: 'کام لەمانە وەک یادگەی کاتی (Volatile memory) دادەنرێت؟',
          type: 'multipleChoice',
          options: ['RAM', 'ROM', 'HDD', 'SSD'],
          correctAnswer: 'RAM',
        },
        {
          id: 'q1_3',
          questionText: 'بەشی سەرەکی و گرنگی ڕەقەکاڵا کە هەموو بەشەکانی تری پێوە دەبەسترێتەوە پێی دەوترێت: ______',
          type: 'fillInBlank',
          correctAnswer: 'Motherboard',
        },
      ],
    },
  ];

  const initialFlashcards = [
    {
      id: 'c1',
      front: 'مۆدێلی OSI چییە؟',
      back: 'ڕێکخراوێکە بۆ لێکتێگەیشتنی پرۆتۆکۆلەکانی تۆڕ لە ٧ چینی جیاوازدا.',
    },
    {
      id: 'c2',
      front: 'کارکردنی CPU چییە؟',
      back: 'ئامێری سەرەکی جێبەجێکردنی فەرمانەکان و پرۆسێسەکردنی زانیارییەکان لە کۆمپیوتەردا.',
    },
  ];

  const initialReminders = [
    {
      id: 'rem_1',
      title: 'ڕادەستکردنی ڕاپۆرتی پڕۆسێسەکانی OS',
      deadline: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000 + 4 * 60 * 60 * 1000).toISOString(),
      courseName: 'سیستەمی کارپێکردن',
      isCompleted: false,
    },
    {
      id: 'rem_2',
      title: 'تاقیکردنەوەی وانەی داتابەیس',
      deadline: new Date(Date.now() + 1 * 24 * 60 * 60 * 1000).toISOString(),
      courseName: 'بنکەی زانیاری',
      isCompleted: false,
    },
  ];

  useEffect(() => {
    const loadAllData = async () => {
      try {
        const storedNotes = await AsyncStorage.getItem('db_notes');
        const storedSchedule = await AsyncStorage.getItem('db_schedule');
        const storedQuizzes = await AsyncStorage.getItem('db_quizzes');
        const storedFlashcards = await AsyncStorage.getItem('db_flashcards');
        const storedReminders = await AsyncStorage.getItem('db_reminders');
        const storedStats = await AsyncStorage.getItem('db_stats');

        if (storedNotes) setNotes(JSON.parse(storedNotes));
        else {
          setNotes(initialNotes);
          await AsyncStorage.setItem('db_notes', JSON.stringify(initialNotes));
        }

        if (storedSchedule) setSchedule(JSON.parse(storedSchedule));
        else {
          setSchedule(initialSchedule);
          await AsyncStorage.setItem('db_schedule', JSON.stringify(initialSchedule));
        }

        if (storedQuizzes) setQuizzes(JSON.parse(storedQuizzes));
        else {
          setQuizzes(initialQuizzes);
          await AsyncStorage.setItem('db_quizzes', JSON.stringify(initialQuizzes));
        }

        if (storedFlashcards) setFlashcards(JSON.parse(storedFlashcards));
        else {
          setFlashcards(initialFlashcards);
          await AsyncStorage.setItem('db_flashcards', JSON.stringify(initialFlashcards));
        }

        if (storedReminders) setReminders(JSON.parse(storedReminders));
        else {
          setReminders(initialReminders);
          await AsyncStorage.setItem('db_reminders', JSON.stringify(initialReminders));
        }

        if (storedStats) setStats(JSON.parse(storedStats));
        else {
          await AsyncStorage.setItem('db_stats', JSON.stringify(stats));
        }
      } catch (e) {
        console.error('Failed to load DB data', e);
      } finally {
        setIsLoading(false);
      }
    };
    loadAllData();
  }, []);

  const addNote = async (note) => {
    const updated = [note, ...notes];
    setNotes(updated);
    await AsyncStorage.setItem('db_notes', JSON.stringify(updated));
  };

  const updateNote = async (updatedNote) => {
    const updated = notes.map(n => n.id === updatedNote.id ? updatedNote : n);
    setNotes(updated);
    await AsyncStorage.setItem('db_notes', JSON.stringify(updated));
  };

  const deleteNote = async (noteId) => {
    const updated = notes.filter(n => n.id !== noteId);
    setNotes(updated);
    await AsyncStorage.setItem('db_notes', JSON.stringify(updated));
  };

  const addScheduleItem = async (item) => {
    const updated = [...schedule, item];
    setSchedule(updated);
    await AsyncStorage.setItem('db_schedule', JSON.stringify(updated));
  };

  const deleteScheduleItem = async (itemId) => {
    const updated = schedule.filter(s => s.id !== itemId);
    setSchedule(updated);
    await AsyncStorage.setItem('db_schedule', JSON.stringify(updated));
  };

  const addQuiz = async (quiz) => {
    const updated = [quiz, ...quizzes];
    setQuizzes(updated);
    await AsyncStorage.setItem('db_quizzes', JSON.stringify(updated));
  };

  const addFlashcard = async (card) => {
    const updated = [...flashcards, card];
    setFlashcards(updated);
    await AsyncStorage.setItem('db_flashcards', JSON.stringify(updated));
  };

  const clearFlashcards = async () => {
    setFlashcards([]);
    await AsyncStorage.setItem('db_flashcards', JSON.stringify([]));
  };

  const addReminder = async (reminder) => {
    const updated = [...reminders, reminder];
    setReminders(updated);
    await AsyncStorage.setItem('db_reminders', JSON.stringify(updated));
  };

  const toggleReminder = async (id) => {
    const updated = reminders.map(r => r.id === id ? { ...r, isCompleted: !r.isCompleted } : r);
    setReminders(updated);
    await AsyncStorage.setItem('db_reminders', JSON.stringify(updated));
  };

  const deleteReminder = async (id) => {
    const updated = reminders.filter(r => r.id !== id);
    setReminders(updated);
    await AsyncStorage.setItem('db_reminders', JSON.stringify(updated));
  };

  const updateStats = async (newStats) => {
    setStats(newStats);
    await AsyncStorage.setItem('db_stats', JSON.stringify(newStats));
  };

  const incrementPomodoros = () => {
    const newStats = { ...stats, completedPomodoros: stats.completedPomodoros + 1 };
    updateStats(newStats);
  };

  const incrementQuizzesTaken = () => {
    const newStats = { ...stats, quizzesTaken: stats.quizzesTaken + 1 };
    updateStats(newStats);
  };

  const incrementFlashcardsFlipped = () => {
    const newStats = { ...stats, flashcardsFlipped: stats.flashcardsFlipped + 1 };
    updateStats(newStats);
  };

  return (
    <DatabaseContext.Provider value={{
      notes, schedule, quizzes, flashcards, reminders, stats, isLoading,
      addNote, updateNote, deleteNote, addScheduleItem, deleteScheduleItem,
      addQuiz, addFlashcard, clearFlashcards, addReminder, toggleReminder, deleteReminder,
      incrementPomodoros, incrementQuizzesTaken, incrementFlashcardsFlipped
    }}>
      {children}
    </DatabaseContext.Provider>
  );
};

export const useDatabase = () => {
  const context = useContext(DatabaseContext);
  if (!context) {
    throw new Error('useDatabase must be used within a DatabaseProvider');
  }
  return context;
};
