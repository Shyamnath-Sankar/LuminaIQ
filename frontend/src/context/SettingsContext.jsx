import React, { createContext, useContext, useState, useEffect } from 'react';

const SettingsContext = createContext();

export const useSettings = () => {
    const context = useContext(SettingsContext);
    if (!context) {
        throw new Error('useSettings must be used within a SettingsProvider');
    }
    return context;
};

export const SettingsProvider = ({ children }) => {
    const [settings, setSettings] = useState(() => {
        const saved = localStorage.getItem('lumina_settings');
        return saved ? JSON.parse(saved) : {
            bookIsolation: true,
            darkMode: false,
            pomodoroWork: 25,
            pomodoroBreak: 5,
            pomodoroLongBreak: 15,
            pomodoroAutoStart: false,
            studyReminders: true,
            reminderTime: '09:00',
            soundEnabled: true,
            showStreaks: true,
            compactMode: false,
            tutorStyle: 'balanced',
            quizDifficulty: 'adaptive',
        };
    });

    useEffect(() => {
        localStorage.setItem('lumina_settings', JSON.stringify(settings));
        
        if (settings.darkMode) {
            document.documentElement.classList.add('dark');
        } else {
            document.documentElement.classList.remove('dark');
        }
    }, [settings]);

    const updateSetting = (key, value) => {
        setSettings(prev => ({ ...prev, [key]: value }));
    };

    const resetSettings = () => {
        localStorage.removeItem('lumina_settings');
        window.location.reload();
    };

    return (
        <SettingsContext.Provider value={{ settings, updateSetting, resetSettings }}>
            {children}
        </SettingsContext.Provider>
    );
};

export default SettingsContext;
