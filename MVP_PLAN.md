# NeighbourCharge MVP - Project Plan

## 1. Project Structure

```
neighbourcharge/
├── public/
│   ├── icons/
│   └── images/
├── src/
│   ├── app/
│   │   ├── layout.tsx          # Root layout
│   │   ├── page.tsx            # Home/Map page
│   │   ├── auth/
│   │   │   ├── signup/
│   │   │   │   └── page.tsx
│   │   │   ├── login/
│   │   │   │   └── page.tsx
│   │   │   └── callback/
│   │   │       └── route.ts    # OAuth callback
│   │   ├── dashboard/
│   │   │   ├── layout.tsx      # Dashboard layout
│   │   │   ├── page.tsx        # User's charging points
│   │   │   ├── add-charger/
│   │   │   │   └── page.tsx
│   │   │   └── my-bookings/
│   │   │       └── page.tsx
│   │   ├── charger/
│   │   │   └── [id]/
│   │   │       └── page.tsx    # Charger detail page
│   │   └── api/
│   │       ├── auth/
│   │       │   ├── signup/
│   │       │   │   └── route.ts
│   │       │   ├── login/
│   │       │   │   └── route.ts
│   │       │   └── logout/
│   │       │       └── route.ts
│   │       ├── chargers/
│   │       │   ├── route.ts    # GET chargers, POST create
│   │       │   └── [id]/
│   │       │       ├── route.ts # GET single, PUT update
│   │       │       └── nearby/
│   │       │           └── route.ts
│   │       ├── bookings/
│   │       │   ├── route.ts    # GET bookings, POST create
│   │       │   └── [id]/
│   │       │       └── route.ts # GET single
│   │       └── users/
│   │           └── me/
│   │               └── route.ts # GET current user
│   ├── components/
│   │   ├── Map.tsx             # Google Map component
│   │   ├── ChargerCard.tsx     # Charger info card
│   │   ├── ChargerForm.tsx     # Add/Edit charger form
│   │   ├── BookingModal.tsx    # Booking modal
│   │   ├── Navbar.tsx          # Navigation bar
│   │   ├── ProtectedRoute.tsx  # Auth wrapper
│   │   └── LoadingSpinner.tsx
│   ├── lib/
│   │   ├── supabase.ts         # Supabase client
│   │   ├── auth.ts             # Auth helpers
│   │   ├── maps.ts             # Google Maps helpers
│   │   └── types.ts            # TypeScript types
│   ├── hooks/
│   │   ├── useAuth.ts          # Auth context hook
│   │   ├── useLocation.ts      # Geolocation hook
│   │   └── useChargers.ts      # Chargers data hook
│   ├── context/
│   │   └── AuthContext.tsx     # Auth provider
│   └── styles/
│       └── globals.css         # Tailwind globals
├── .env.local                  # Environment variables
├── .gitignore
├── package.json
├── tsconfig.json
├── tailwind.config.ts
├── next.config.js
└── README.md
```

---

## 2. Database Schema (Supabase)

### Tables

#### `users`
```sql
id                UUID          PRIMARY KEY (auth.uid)
email             VARCHAR       NOT NULL UNIQUE
full_name         VARCHAR
phone             VARCHAR
avatar_url        VARCHAR
bio               TEXT
created_at        TIMESTAMP     DEFAULT NOW()
updated_at        TIMESTAMP     DEFAULT NOW()
```

#### `chargers`
```sql
id                UUID          PRIMARY KEY
user_id           UUID          FOREIGN KEY (users.id) NOT NULL
name              VARCHAR       NOT NULL
description       TEXT
location_lat      DECIMAL(10,8) NOT NULL
location_lng      DECIMAL(11,8) NOT NULL
address           VARCHAR       NOT NULL
charger_type      VARCHAR       (AC, DC, SuperCharger)
power_kw          INT           (e.g., 7, 11, 22, 50)
price_per_hour    DECIMAL(10,2) NOT NULL
availability      VARCHAR       (available, booked, maintenance)
image_url         VARCHAR
created_at        TIMESTAMP     DEFAULT NOW()
updated_at        TIMESTAMP     DEFAULT NOW()
```

#### `bookings`
```sql
id                UUID          PRIMARY KEY
charger_id        UUID          FOREIGN KEY (chargers.id) NOT NULL
user_id           UUID          FOREIGN KEY (users.id) NOT NULL
start_time        TIMESTAMP     NOT NULL
end_time          TIMESTAMP     NOT NULL
status            VARCHAR       (pending, confirmed, completed, cancelled)
notes             TEXT
created_at        TIMESTAMP     DEFAULT NOW()
updated_at        TIMESTAMP     DEFAULT NOW()
```

#### `reviews` (Optional for MVP+)
```sql
id                UUID          PRIMARY KEY
charger_id        UUID          FOREIGN KEY (chargers.id)
user_id           UUID          FOREIGN KEY (users.id)
rating            INT           (1-5)
comment           TEXT
created_at        TIMESTAMP     DEFAULT NOW()
```

### Row Level Security (RLS) Policies

- **Users table**: Users can read all profiles but only update their own
- **Chargers table**: Anyone can read, authenticated users can create, only owners can update/delete
- **Bookings table**: Users can read their own bookings and all charger bookings for that charger, owners can see all bookings for their chargers

---

## 3. Routes & Pages Overview

| Route | Component | Purpose | Auth | Description |
|-------|-----------|---------|------|-------------|
| `/` | `app/page.tsx` | Home/Map | ❌ | Display map with all chargers, filtering/search |
| `/auth/signup` | `auth/signup/page.tsx` | Sign Up | ❌ | Registration form |
| `/auth/login` | `auth/login/page.tsx` | Log In | ❌ | Login form |
| `/charger/[id]` | `charger/[id]/page.tsx` | Charger Detail | ❌ | View charger details, book button |
| `/dashboard` | `dashboard/page.tsx` | Dashboard | ✅ | User's chargers, bookings overview |
| `/dashboard/add-charger` | `dashboard/add-charger/page.tsx` | Add Charger | ✅ | Form to add new charger |
| `/dashboard/my-bookings` | `dashboard/my-bookings/page.tsx` | My Bookings | ✅ | User's booking requests/history |

### API Routes

| Endpoint | Method | Purpose | Auth |
|----------|--------|---------|------|
| `/api/auth/signup` | POST | Register user | ❌ |
| `/api/auth/login` | POST | Login user | ❌ |
| `/api/auth/logout` | POST | Logout user | ✅ |
| `/api/chargers` | GET | List all chargers | ❌ |
| `/api/chargers` | POST | Create new charger | ✅ |
| `/api/chargers/[id]` | GET | Get single charger | ❌ |
| `/api/chargers/[id]` | PUT | Update charger | ✅ Owner only |
| `/api/chargers/[id]` | DELETE | Delete charger | ✅ Owner only |
| `/api/chargers/[id]/nearby` | GET | Get nearby chargers (radius) | ❌ |
| `/api/bookings` | GET | Get user's bookings | ✅ |
| `/api/bookings` | POST | Create booking request | ✅ |
| `/api/bookings/[id]` | GET | Get booking details | ✅ |
| `/api/bookings/[id]` | PUT | Update booking status | ✅ Owner/User |
| `/api/users/me` | GET | Get current user profile | ✅ |

---

## 4. Step-by-Step Setup Instructions

### Phase 1: Environment Setup

1. **Create Next.js project**
   ```bash
   npx create-next-app@latest neighbourcharge --typescript --tailwind --app
   cd neighbourcharge
   ```

2. **Install dependencies**
   ```bash
   npm install @supabase/supabase-js
   npm install @react-google-maps/api
   npm install zustand  # or use Context API (included in plan)
   npm install dotenv
   ```

3. **Set up environment variables** (`.env.local`)
   ```
   NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_key
   NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_key
   ```

### Phase 2: Supabase Setup

1. **Create Supabase project** at supabase.com
2. **Create tables** (SQL scripts provided)
3. **Enable Authentication**
   - Go to Authentication → Providers → Email
   - Enable email/password auth
4. **Set up Google OAuth** (optional for MVP)
5. **Enable RLS** on all tables
6. **Create RLS policies** for each table

### Phase 3: Google Maps API

1. **Create Google Cloud project**
2. **Enable Maps JavaScript API**
3. **Create API key** and restrict to domains
4. **Add to `.env.local`**

### Phase 4: Development

1. **Implement Auth Context** (AuthContext.tsx)
   - Login/Signup logic
   - Session management
   - Protected routes

2. **Build Core Components**
   - Map component with charger markers
   - Charger card (info display)
   - Booking modal
   - Forms (add charger, booking)

3. **Create Pages**
   - Start with home page (map view)
   - Then auth pages
   - Then dashboard pages

4. **Connect to Supabase API**
   - Create helpers for CRUD operations
   - Implement error handling

### Phase 5: Testing & Deployment

1. **Test locally**
   ```bash
   npm run dev
   ```

2. **Deploy to Vercel**
   ```bash
   npm run build
   git push
   ```

---

## 5. Key Features (MVP)

✅ **Must Have**
- User authentication (email/password)
- Add/edit/delete own chargers
- View all chargers on map
- View charger details
- Request booking (contact owner)
- Mobile-responsive design

⭐ **Nice to Have (MVP+)**
- Google OAuth login
- Rating/reviews system
- Booking calendar view
- Push notifications
- Advanced filters (charger type, price range)
- Photo upload for chargers

---

## 6. UI/UX Flow

### User Journey 1: Listing a Charger
1. Sign up → 2. Verify email → 3. Dashboard → 4. Add Charger → 5. Fill form (name, location, price, etc.) → 6. Publish

### User Journey 2: Finding & Booking
1. Home → 2. View map with chargers → 3. Click charger marker → 4. See details card → 5. Request booking → 6. Contact owner

### Design Principles (Airbnb-inspired)
- Clean white/light background
- Blue accent color for CTAs
- Large clear photos
- Minimal text
- Icons for charger types
- Distance/time info on cards
- Star ratings (if included)

---

## 7. Dependencies Summary

```json
{
  "dependencies": {
    "next": "^14.0.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@supabase/supabase-js": "^2.38.0",
    "@react-google-maps/api": "^2.19.0",
    "tailwindcss": "^3.3.0"
  }
}
```

---

## Next Steps

1. ✅ Review this plan
2. ⬜ Set up Supabase & Google Maps API keys
3. ⬜ Create Next.js project with dependencies
4. ⬜ Create Supabase tables & RLS policies
5. ⬜ Build auth context & protected routes
6. ⬜ Implement Map component
7. ⬜ Create API routes
8. ⬜ Build pages & components
9. ⬜ Test and deploy

---

**Notes for MVP:**
- No payment integration (just booking requests)
- No real-time notifications
- Simple email contact instead of in-app messaging
- Basic design without complex animations
- No user reviews/ratings in MVP (can add later)
