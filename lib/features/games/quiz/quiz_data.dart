import 'quiz_model.dart';

class QuizData {
  static const List<QuizCategory> categories = [
    QuizCategory(
      name: "Maths",
      emoji: "🔢",
      gradientColors: [0xFF6A11CB, 0xFF2575FC],
    ),
    QuizCategory(
      name: "Logical",
      emoji: "🧠",
      gradientColors: [0xFFFF416C, 0xFFFF4B2B],
    ),
    QuizCategory(
      name: "Science",
      emoji: "🔬",
      gradientColors: [0xFF11998E, 0xFF38EF7D],
    ),
    QuizCategory(
      name: "General",
      emoji: "🌍",
      gradientColors: [0xFFF7971E, 0xFFFFD200],
    ),
    QuizCategory(
      name: "Current Affairs",
      emoji: "📰",
      gradientColors: [0xFF834D9B, 0xFFD04ED6],
    ),
    QuizCategory(
      name: "Technology",
      emoji: "💻",
      gradientColors: [0xFF0F2027, 0xFF203A43],
    ),
    QuizCategory(
      name: "Sports",
      emoji: "⚽",
      gradientColors: [0xFF56AB2F, 0xFFA8E063],
    ),
  ];

  static List<Question> allQuestions = [
    // ─────────────── MATHS ───────────────
    Question(questionText: "What is 5 + 7?", options: ["10", "12", "14", "15"], correctAnswerIndex: 1, category: "Maths"),
    Question(questionText: "What is 9 × 3?", options: ["27", "21", "24", "30"], correctAnswerIndex: 0, category: "Maths"),
    Question(questionText: "What is the square root of 144?", options: ["11", "12", "13", "14"], correctAnswerIndex: 1, category: "Maths"),
    Question(questionText: "What is 15% of 200?", options: ["25", "30", "35", "40"], correctAnswerIndex: 1, category: "Maths"),
    Question(questionText: "What is 2 to the power of 8?", options: ["128", "256", "512", "64"], correctAnswerIndex: 1, category: "Maths"),
    Question(questionText: "What is 3/4 as a percentage?", options: ["70%", "75%", "80%", "65%"], correctAnswerIndex: 1, category: "Maths"),
    Question(questionText: "If x + 5 = 12, what is x?", options: ["5", "6", "7", "8"], correctAnswerIndex: 2, category: "Maths"),
    Question(questionText: "What is the LCM of 4 and 6?", options: ["12", "24", "8", "6"], correctAnswerIndex: 0, category: "Maths"),
    Question(questionText: "How many degrees are in a right angle?", options: ["45°", "60°", "90°", "180°"], correctAnswerIndex: 2, category: "Maths"),
    Question(questionText: "What is 1000 ÷ 25?", options: ["35", "40", "45", "50"], correctAnswerIndex: 1, category: "Maths"),
    Question(questionText: "What is -3 × -4?", options: ["-12", "12", "-7", "7"], correctAnswerIndex: 1, category: "Maths"),
    Question(questionText: "What is the area of a circle with radius 7? (π≈22/7)", options: ["144", "154", "164", "174"], correctAnswerIndex: 1, category: "Maths"),

    // ─────────────── LOGICAL ───────────────
    Question(questionText: "Find the next: 2, 4, 8, 16, ?", options: ["18", "20", "32", "24"], correctAnswerIndex: 2, category: "Logical"),
    Question(questionText: "If all Bloops are Razzies and all Razzies are Lazzies, then all Bloops are definitely Lazzies?", options: ["True", "False", "Maybe", "Sometimes"], correctAnswerIndex: 0, category: "Logical"),
    Question(questionText: "Which number comes next: 1, 3, 6, 10, 15, ?", options: ["18", "19", "20", "21"], correctAnswerIndex: 3, category: "Logical"),
    Question(questionText: "A bat and ball cost \$1.10. Bat costs \$1 more than ball. How much is the ball?", options: ["\$0.10", "\$0.05", "\$0.15", "\$0.20"], correctAnswerIndex: 1, category: "Logical"),
    Question(questionText: "What letter comes next: A, C, E, G, ?", options: ["H", "I", "J", "K"], correctAnswerIndex: 1, category: "Logical"),
    Question(questionText: "Mary's father has 5 daughters: Nana, Nene, Nini, Nono. What is the 5th daughter's name?", options: ["Nunu", "Nana", "Mary", "Nene"], correctAnswerIndex: 2, category: "Logical"),
    Question(questionText: "Which is heavier: 1kg of iron or 1kg of feathers?", options: ["Iron", "Feathers", "They weigh the same", "Depends on volume"], correctAnswerIndex: 2, category: "Logical"),
    Question(questionText: "Next in sequence: 2, 6, 12, 20, 30, ?", options: ["38", "40", "42", "44"], correctAnswerIndex: 2, category: "Logical"),
    Question(questionText: "If you have 3 apples and take away 2, how many do YOU have?", options: ["1", "2", "3", "0"], correctAnswerIndex: 1, category: "Logical"),
    Question(questionText: "Which number doesn't belong: 2, 3, 5, 7, 9, 11", options: ["2", "3", "9", "11"], correctAnswerIndex: 2, category: "Logical"),
    Question(questionText: "What comes once in a minute, twice in a moment, but never in a thousand years?", options: ["Second", "Letter M", "Silence", "Time"], correctAnswerIndex: 1, category: "Logical"),
    Question(questionText: "In a race, you overtake the 2nd person. What position are you in?", options: ["1st", "2nd", "3rd", "Last"], correctAnswerIndex: 1, category: "Logical"),

    // ─────────────── SCIENCE ───────────────
    Question(questionText: "Water boils at what temperature (°C)?", options: ["90", "100", "80", "120"], correctAnswerIndex: 1, category: "Science"),
    Question(questionText: "What is the chemical symbol for Gold?", options: ["Go", "Gd", "Au", "Ag"], correctAnswerIndex: 2, category: "Science"),
    Question(questionText: "How many bones are in the adult human body?", options: ["196", "206", "216", "226"], correctAnswerIndex: 1, category: "Science"),
    Question(questionText: "What planet is closest to the Sun?", options: ["Venus", "Earth", "Mercury", "Mars"], correctAnswerIndex: 2, category: "Science"),
    Question(questionText: "What gas do plants absorb from the atmosphere?", options: ["Oxygen", "Nitrogen", "Carbon Dioxide", "Hydrogen"], correctAnswerIndex: 2, category: "Science"),
    Question(questionText: "What is the speed of light (km/s)?", options: ["200,000", "300,000", "400,000", "150,000"], correctAnswerIndex: 1, category: "Science"),
    Question(questionText: "DNA stands for?", options: ["Deoxyribonucleic Acid", "Dinitrogen Acid", "Dynamic Nucleic Acid", "None of these"], correctAnswerIndex: 0, category: "Science"),
    Question(questionText: "What is the powerhouse of the cell?", options: ["Nucleus", "Ribosome", "Mitochondria", "Vacuole"], correctAnswerIndex: 2, category: "Science"),
    Question(questionText: "Which element has the atomic number 1?", options: ["Helium", "Hydrogen", "Oxygen", "Carbon"], correctAnswerIndex: 1, category: "Science"),
    Question(questionText: "What force keeps us on Earth?", options: ["Magnetism", "Gravity", "Friction", "Normal Force"], correctAnswerIndex: 1, category: "Science"),
    Question(questionText: "How many chambers does a human heart have?", options: ["2", "3", "4", "6"], correctAnswerIndex: 2, category: "Science"),
    Question(questionText: "The sun is a?", options: ["Planet", "Moon", "Star", "Asteroid"], correctAnswerIndex: 2, category: "Science"),

    // ─────────────── GENERAL ───────────────
    Question(questionText: "What is the capital of Germany?", options: ["Berlin", "Paris", "Madrid", "Rome"], correctAnswerIndex: 0, category: "General"),
    Question(questionText: "How many continents are on Earth?", options: ["5", "6", "7", "8"], correctAnswerIndex: 2, category: "General"),
    Question(questionText: "Who wrote 'Romeo and Juliet'?", options: ["Dickens", "Shakespeare", "Hemingway", "Austen"], correctAnswerIndex: 1, category: "General"),
    Question(questionText: "What is the largest ocean?", options: ["Atlantic", "Indian", "Arctic", "Pacific"], correctAnswerIndex: 3, category: "General"),
    Question(questionText: "What currency does Japan use?", options: ["Won", "Yuan", "Yen", "Dollar"], correctAnswerIndex: 2, category: "General"),
    Question(questionText: "How many colors are in a rainbow?", options: ["5", "6", "7", "8"], correctAnswerIndex: 2, category: "General"),
    Question(questionText: "What is the capital of Australia?", options: ["Sydney", "Melbourne", "Canberra", "Brisbane"], correctAnswerIndex: 2, category: "General"),
    Question(questionText: "Who painted the Mona Lisa?", options: ["Van Gogh", "Picasso", "Da Vinci", "Raphael"], correctAnswerIndex: 2, category: "General"),
    Question(questionText: "What language is most spoken worldwide?", options: ["English", "Spanish", "Mandarin", "Hindi"], correctAnswerIndex: 2, category: "General"),
    Question(questionText: "How many sides does a hexagon have?", options: ["5", "6", "7", "8"], correctAnswerIndex: 1, category: "General"),
    Question(questionText: "What is the tallest mountain in the world?", options: ["K2", "Kangchenjunga", "Everest", "Lhotse"], correctAnswerIndex: 2, category: "General"),
    Question(questionText: "Which planet is known as the Red Planet?", options: ["Venus", "Jupiter", "Mars", "Saturn"], correctAnswerIndex: 2, category: "General"),

    // ─────────────── CURRENT AFFAIRS ───────────────
    Question(questionText: "Which country hosted the 2024 Olympics?", options: ["France", "Japan", "USA", "Australia"], correctAnswerIndex: 0, category: "Current Affairs"),
    Question(questionText: "Who became the first trillionaire according to reports in 2024?", options: ["Jeff Bezos", "Elon Musk", "Bill Gates", "Warren Buffet"], correctAnswerIndex: 1, category: "Current Affairs"),
    Question(questionText: "Which AI chatbot was launched by OpenAI in late 2022?", options: ["Gemini", "ChatGPT", "Claude", "Bard"], correctAnswerIndex: 1, category: "Current Affairs"),
    Question(questionText: "Which country won the FIFA World Cup 2022?", options: ["Brazil", "Germany", "France", "Argentina"], correctAnswerIndex: 3, category: "Current Affairs"),
    Question(questionText: "What is the name of Apple's AI assistant introduced in 2024?", options: ["Siri AI", "Apple GPT", "Apple Intelligence", "iMind"], correctAnswerIndex: 2, category: "Current Affairs"),
    Question(questionText: "Which social media platform rebranded to 'X'?", options: ["Facebook", "Twitter", "Instagram", "Snapchat"], correctAnswerIndex: 1, category: "Current Affairs"),
    Question(questionText: "Who is the Secretary-General of the United Nations (2024)?", options: ["Ban Ki-moon", "Kofi Annan", "António Guterres", "Kurt Waldheim"], correctAnswerIndex: 2, category: "Current Affairs"),
    Question(questionText: "In 2023, which spacecraft landed on the Moon's south pole?", options: ["Apollo 25", "Chandrayaan-3", "Artemis 1", "Luna 25"], correctAnswerIndex: 1, category: "Current Affairs"),
    Question(questionText: "COP28 climate summit was held in which city?", options: ["Glasgow", "Paris", "Dubai", "Cairo"], correctAnswerIndex: 2, category: "Current Affairs"),
    Question(questionText: "Which country launched the 'Belt and Road Initiative'?", options: ["USA", "China", "Russia", "India"], correctAnswerIndex: 1, category: "Current Affairs"),
    Question(questionText: "Which streaming platform released the series 'Wednesday'?", options: ["HBO", "Disney+", "Netflix", "Amazon Prime"], correctAnswerIndex: 2, category: "Current Affairs"),
    Question(questionText: "Sam Altman is the CEO of which AI company?", options: ["Google DeepMind", "OpenAI", "Anthropic", "Meta AI"], correctAnswerIndex: 1, category: "Current Affairs"),

    // ─────────────── TECHNOLOGY ───────────────
    Question(questionText: "What does 'HTTP' stand for?", options: ["HyperText Transfer Protocol", "High Text Transfer Protocol", "Hybrid Text Transfer Protocol", "HyperText Type Protocol"], correctAnswerIndex: 0, category: "Technology"),
    Question(questionText: "Which company developed the Android OS?", options: ["Apple", "Microsoft", "Google", "Samsung"], correctAnswerIndex: 2, category: "Technology"),
    Question(questionText: "What does 'CPU' stand for?", options: ["Central Programming Unit", "Central Processing Unit", "Computer Processing Unit", "Core Processing Unit"], correctAnswerIndex: 1, category: "Technology"),
    Question(questionText: "What language is primarily used for web pages?", options: ["Python", "Java", "HTML", "C++"], correctAnswerIndex: 2, category: "Technology"),
    Question(questionText: "What does 'Wi-Fi' stand for?", options: ["Wireless Fidelity", "Wide-Field Internet", "Wireless Fibre", "None of these"], correctAnswerIndex: 0, category: "Technology"),
    Question(questionText: "In computing, what is a 'byte' made of?", options: ["4 bits", "8 bits", "16 bits", "32 bits"], correctAnswerIndex: 1, category: "Technology"),
    Question(questionText: "Who founded Microsoft?", options: ["Steve Jobs", "Mark Zuckerberg", "Bill Gates", "Elon Musk"], correctAnswerIndex: 2, category: "Technology"),
    Question(questionText: "What does 'AI' stand for in computing?", options: ["Automated Intelligence", "Artificial Intelligence", "Advanced Internet", "Algorithmic Intelligence"], correctAnswerIndex: 1, category: "Technology"),
    Question(questionText: "What is the most used programming language (2024)?", options: ["Python", "Java", "C#", "JavaScript"], correctAnswerIndex: 3, category: "Technology"),
    Question(questionText: "What does 'URL' stand for?", options: ["Uniform Resource Locator", "Universal Resource Link", "Uniform Resource Link", "Universal Resource Locator"], correctAnswerIndex: 0, category: "Technology"),
    Question(questionText: "Which company makes the 'iPhone'?", options: ["Samsung", "Google", "Apple", "Sony"], correctAnswerIndex: 2, category: "Technology"),
    Question(questionText: "What is 'Open Source' software?", options: ["Free software only", "Closed code software", "Software with publicly available source code", "Government software"], correctAnswerIndex: 2, category: "Technology"),

    // ─────────────── SPORTS ───────────────
    Question(questionText: "How many players are in a football (soccer) team?", options: ["9", "10", "11", "12"], correctAnswerIndex: 2, category: "Sports"),
    Question(questionText: "How many Grand Slams are in tennis?", options: ["2", "3", "4", "5"], correctAnswerIndex: 2, category: "Sports"),
    Question(questionText: "Which country invented cricket?", options: ["Australia", "India", "England", "South Africa"], correctAnswerIndex: 2, category: "Sports"),
    Question(questionText: "In which sport is a 'birdie' a term?", options: ["Baseball", "Golf", "Tennis", "Badminton"], correctAnswerIndex: 1, category: "Sports"),
    Question(questionText: "How many rings are there in the Olympic logo?", options: ["3", "4", "5", "6"], correctAnswerIndex: 2, category: "Sports"),
    Question(questionText: "Who is known as 'King James' in basketball?", options: ["Kobe Bryant", "Michael Jordan", "LeBron James", "Shaquille O'Neal"], correctAnswerIndex: 2, category: "Sports"),
    Question(questionText: "What is the maximum score in a perfect bowling game?", options: ["200", "250", "300", "350"], correctAnswerIndex: 2, category: "Sports"),
    Question(questionText: "In cricket, how many balls are in an over?", options: ["4", "5", "6", "8"], correctAnswerIndex: 2, category: "Sports"),
    Question(questionText: "Which country has won the most FIFA World Cups?", options: ["Germany", "Argentina", "Brazil", "Italy"], correctAnswerIndex: 2, category: "Sports"),
    Question(questionText: "In formula 1, how many points does 1st place get?", options: ["10", "20", "25", "30"], correctAnswerIndex: 2, category: "Sports"),
    Question(questionText: "What sport does Novak Djokovic play?", options: ["Football", "Cricket", "Tennis", "Badminton"], correctAnswerIndex: 2, category: "Sports"),
    Question(questionText: "How many holes are in a standard round of golf?", options: ["9", "12", "18", "21"], correctAnswerIndex: 2, category: "Sports"),
  ];

  static List<Question> getQuestionsForCategory(String category) {
    final filtered = allQuestions.where((q) => q.category == category).toList();
    filtered.shuffle();
    return filtered.take(10).toList();
  }
}
