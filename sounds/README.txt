PUT YOUR CUSTOM ALARM SOUND HERE
================================

Add your sound file to this folder and name it:

    alarm.mp3

(The app loads "pkg:/sounds/alarm.mp3".)

Supported formats on Roku: MP3, AAC, WAV, FLAC.
If you want to use a different format, either:
  - rename/convert your file to alarm.mp3, OR
  - edit the URL in components/MainScene.brs (search for "alarm.mp3")
    to match your filename, e.g. "pkg:/sounds/alarm.wav".

The sound is played on a loop while the alarm is ringing and stops when
you press OK on the remote.
