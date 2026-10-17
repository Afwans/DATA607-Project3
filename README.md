# CS355 Project 3
This is a full-featured Quiz Web App built using HTML, CSS, and JavaScript, with a Node.js + Express backend that serves questions from a JSON file. The app supports a clean UI, interactive gameplay, and advanced features like dark mode, progress tracking, review mode, and more.

Github repo Link: https://github.com/Afwans/CS355-project-3-

Website link: https://quiz-app-rrfw.onrender.com


------------------------------------------------------------------------------------------------------------------------------------------


🚀 Features


🎮 Gameplay & Quiz Mechanics

✅ Start screen with question count selector

✅ Fetches randomized questions from the server

✅ Multiple choice questions with randomized answer order

✅ Practice Mode and Timed Mode support

✅ Timer per question (10 seconds) with timeout popup

✅ Progress tracker (text + animated progress bar)

✅ Review mode (shows your answers vs. correct ones)

✅ End-of-quiz score display with feedback message

✅ Final animated message based on score

✅ Replay functionality (restart quiz easily)



🧑‍💻 User System & Personalization

✅ Full user authentication with signup, login, logout

✅ Account handling with session-based security

✅ User storage and maintenance via backend/database

✅ Customizable user profiles with profile picture

✅ Editable bio, username, email, and password

✅ Greeting message upon login

✅ Avatar selector with image preview and update

✅ Seamless profile update experience

✅ Profile game history tracking and display



📊 Leaderboard & Scoring

✅ Real-time leaderboard showcasing top-performing users

✅ Game score + time-per-question tracking

✅ Daily scores stored in MongoDB (if Daily Quiz added)



🌙 UI Enhancements

✅ Dark mode toggle

✅ Sound mode toggle

✅ Sound effects for correct, wrong, and timeout

✅ Emoji rain animations for right/wrong answers

✅ Mobile-friendly and responsive layout

✅ Timer visually styled and placed under progress bar



🎯 Advanced Features

✅ Daily Quiz Challenge (in progress / planned)

✅ Practice vs Timed mode distinction

✅ Final popup and timeout popup messages

✅ Layout built with modular EJS partials

✅ Environment-based secret handling via .env


------------------------------------------------------------------------------------------------------------------------------------------


🧠 Technologies Used


🖥️ Frontend

HTML – for structure and layout

CSS – custom styles including dark mode and animations

JavaScript – for quiz logic, user interaction, sound effects, and timers

EJS (Embedded JavaScript) – dynamic templates rendered on the server


🧰 Backend

Node.js – runtime for executing server-side logic

Express.js – lightweight web framework for routing and middleware

Express-session – handles user login sessions securely


🗃️ Data & Persistence

MongoDB with Mongoose – stores users, games, avatars, scores, and profiles

Static JSON file (originally) – for basic question storage (if used in early version)

Open Trivia DB (optional upgrade) – API for dynamic quiz content

dotenv – loads environment variables from .env for security

------------------------------------------------------------------------------------------------------------------------------------------

 
Project Structure

quiz-app/

│

├── bin/

│   └── www                   

│

├── controllers/              

│   ├── authController.js

│   ├── leaderboardController.js

│   ├── profileController.js

│   ├── quizController.js

│   └── settingsController.js

│

├── routes/                  

│   ├── auth.js

│   ├── index.js

│   ├── leaderboard.js

│   ├── profile.js

│   ├── quiz.js

│   └── settings.js

│

├── models/                  

│   ├── Avatar.js

│   ├── Game.js

│   └── User.js

│

├── views/                    

│   ├── auth/                

│   │   ├── signin.ejs

│   │   └── signup.ejs

│   │

│   ├── main/                 

│   │   ├── index.ejs

│   │   ├── leaderboard.ejs

│   │   ├── profile.ejs

│   │   ├── quiz.ejs

│   │   ├── results.ejs

│   │   └── settings.ejs

│   │

│   ├── partials/             

│   │   ├── header.ejs

│   │   └── popup.ejs

│   │

│   └── error.ejs            

│

├── public/                 
│   ├── JavaScript/          

│   │   ├── darkmode.js

│   │   ├── navbar.js

│   │   ├── profileSettings.js

│   │   └── script.js

│   │

│   ├── Stylesheets/        

│   │   ├── auth.css

│   │   ├── popup.css

│   │   ├── quiz.css

│   │   ├── profile.css

│   │   ├── setting.css

│   │   ├── bass.css

│   │   └── darkmode.css

│   │

│   ├── Stylesheets2/        

│   │   ├── homepage.css

│   │   ├── style.css

│   │   └── settings.css

│   │

│   ├── sound/             

│   └── Images/             

│

├── .env                     

├── app.js                   

├── package.json             

└── README.md               


------------------------------------------------------------------------------------------------------------------------------------------



📦 Setup Instructions


1. Clone the repo:

   git clone https://github.com/Afwans/quiz-app.git

   cd quiz-app

3. Install dependencies:

   npm install


4. Create .env file:

Then add the following inside:

MONGO_URI=mongodb+srv://<username>:<password>@cluster0.mongodb.net/quiz-app

PORT=3000


5. Start the server:

   npm start / node app.js

6. Access the app:

   Visit http://localhost:3000 in your browser
   
7. To access the App online, please use this link

   Visit [quiz-app-rrfw.onrender.com]

   
🧑 Authors
1. Mohd Afwan Shaikh [https://www.linkedin.com/in/mohdafwan/] [https://afwans.github.io/]
2. Nageen Saira [https://www.linkedin.com/in/nageensaira/] [https://nageen123-saira.github.io/port/]
3. Arjun Chhabra [https://www.linkedin.com/in/arjun-chhabra-22150b247/] [https://github.com/Jun1604] 
4. Sadia Sharmin [https://www.linkedin.com/in/sadiasharmin16/] [https://ssharmin28.github.io/]


Contribution to the project 

| Name  | Contribution | Worked on 
| ----- | ----- | ----- |
| Mohd Afwan Shaikh  | Backend + Core Features | Project Architecture & Planning, Backend API Setup (Node.js + Express), User storage and maintenance (via backend/database), Account Handling and Security, Real-time leaderboard showcasing top-performing users, Game history tracking and display, Final Message based on Scores, Greeting Message, Deployment & Error Handling, Assistance in all modules for debugging & integration, and more |
| Arjun Chhabra | Frontend Developer - Core UI | Start screen with question count selector, Multiple choice questions UI, Shuffled answer order, Timer per question (10 seconds), End-of-quiz score display, Review mode (show your answers vs. correct), Replay functionality, Practice mode, Real-time leaderboard showcasing top-performing users, integration, User storage and maintenance, and more |
| Nageen Saira | UI interaction & User Management | Designed and built Welcome Page, Sign In, and Sign Up pages with proper form validation and user flow, Implemented Sound Toggle Button with audio logic for correct and incorrect answers, Added animated Happy/Sad Emojis on answer feedback, Created Popup Messages for quiz timeout and end-of-quiz results (celebration, emoji, and alerts), Integrated interactive elements into the UI to enhance user engagement and accessibility|
| Sadia Sharmin | Advanced Features & UI Enhancements | Customizable user profiles, Dark mode toggle, Sound mode toggle, Frontend Sound Integration Logic, Navbar/Settings enhancements, UI Responsiveness across all pages, CSS Styling for the entire project (consistency & theme), integration,  Progress tracker (text + bar),  Final Message based on Scores, Profile Page Styling, Settings Page UI and logic, integration, and more|

Notes:
* All teammates contributed to testing, feedback, and final tweaks.

* Regular team discussions were held for feature planning and integration.

* Teamwork and communication were essential for project success.



📄 License

This project is strictly limited to use by Mohd Afwan Shaikh, Arjun Chhabra, Sadia Sharmin, and Nageen Saira. Unauthorized usage, distribution, or modification by others is strictly prohibited and may lead to legal action.
If found in use outside of the authorized team, it can result in a lawsuit.


