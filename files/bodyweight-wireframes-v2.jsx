import { useState, useEffect } from "react";

const ALL_EXERCISES = [
  { name: "Push-Ups", icon: "💪", color: "#E8722A", group: "Upper Push", sets: [34, 24, 22, 20, 18], level: 2, day: 8, totalDays: 19, total: 118, mode: "confirm", rest: 60 },
  { name: "Squats", icon: "🦵", color: "#0D9488", group: "Lower", sets: [40, 22, 18, 28], level: 2, day: 10, totalDays: 19, total: 108, mode: "realtime", rest: 90 },
  { name: "Sit-Ups", icon: "🔥", color: "#D4A017", group: "Core Flexion", sets: [32, 18, 16, 14, 14, 12], level: 2, day: 6, totalDays: 18, total: 106, mode: "confirm", rest: 45 },
  { name: "Pull-Ups", icon: "🏋️", color: "#DC2626", group: "Upper Pull", sets: [7, 6, 5, 5], level: 2, day: 4, totalDays: 19, total: 23, mode: "confirm", rest: 90 },
  { name: "Glute Bridges", icon: "🍑", color: "#8B5CF6", group: "Lower", sets: [42, 20, 16, 26], level: 2, day: 6, totalDays: 19, total: 104, mode: "realtime", rest: 75, warning: "Squat test tomorrow — consider resting" },
  { name: "Dead Bugs", icon: "🪲", color: "#16A34A", group: "Core Stability", sets: [14, 10, 8, 7], level: 2, day: 6, totalDays: 18, total: 39, mode: "realtime", rest: 45 },
];

const TEST_EXERCISE = { name: "Push-Ups", icon: "💪", color: "#E8722A", target: 50, level: 2 };

const Card = ({ children, style, onClick }) => (
  <div onClick={onClick} style={{ background: "#18181B", borderRadius: 16, border: "1px solid #2A2A2E", ...style }}>{children}</div>
);

export default function App() {
  const [appState, setAppState] = useState("enrol");
  const [enrolled, setEnrolled] = useState(new Set());
  const [screen, setScreen] = useState("today");
  const [completed, setCompleted] = useState(new Set());
  const [activeEx, setActiveEx] = useState(null);
  const [currentSet, setCurrentSet] = useState(0);
  const [reps, setReps] = useState(0);
  const [resting, setResting] = useState(false);
  const [restTime, setRestTime] = useState(60);
  const [exDone, setExDone] = useState(false);
  const [setPhase, setSetPhase] = useState("count"); // "ready" | "active" | "count" | "confirm"
  const [elapsed, setElapsed] = useState(0);
  const [showTest, setShowTest] = useState(false);
  const [testReps, setTestReps] = useState(0);
  const [testDone, setTestDone] = useState(false);
  const [watchView, setWatchView] = useState("set");
  const [watchReps, setWatchReps] = useState(0);

  const exercises = ALL_EXERCISES.filter((_, i) => enrolled.has(i));

  useEffect(() => {
    let iv;
    if (resting && restTime > 0) iv = setInterval(() => setRestTime(t => t - 1), 1000);
    else if (resting && restTime === 0) { setResting(false); setRestTime(60); }
    return () => clearInterval(iv);
  }, [resting, restTime]);

  useEffect(() => {
    let iv;
    if (setPhase === "active") iv = setInterval(() => setElapsed(t => t + 1), 1000);
    return () => clearInterval(iv);
  }, [setPhase]);

  const toggleEnrol = (i) => {
    const next = new Set(enrolled);
    next.has(i) ? next.delete(i) : next.add(i);
    setEnrolled(next);
  };

  const startEx = (i) => {
    const ex = ALL_EXERCISES[i];
    setActiveEx(i); setCurrentSet(0); setReps(0); setResting(false); setExDone(false);
    setSetPhase(ex.mode === "confirm" ? "ready" : "count"); setElapsed(0);
    setRestTime(ex.rest); setScreen("workout");
  };

  const doneSet = () => {
    const ex = ALL_EXERCISES[activeEx];
    if (currentSet < ex.sets.length - 1) {
      setResting(true); setRestTime(ex.rest); setCurrentSet(s => s + 1); setReps(0);
      setSetPhase(ex.mode === "confirm" ? "ready" : "count"); setElapsed(0);
    } else { setCompleted(p => new Set([...p, activeEx])); setExDone(true); }
  };

  const fmt = s => `${Math.floor(s/60)}:${(s%60).toString().padStart(2,"0")}`;

  const remaining = exercises.filter((_, i) => {
    const realIdx = ALL_EXERCISES.indexOf(exercises[i]);
    return !completed.has(realIdx);
  });

  // --- ENROLMENT SCREEN ---
  if (appState === "enrol") {
    const groups = [
      { label: "Upper Push", indices: [0] },
      { label: "Upper Pull", indices: [3] },
      { label: "Lower", indices: [1, 4] },
      { label: "Core", indices: [2, 5] },
    ];
    const groupCount = new Set(
      [...enrolled].map(i => ALL_EXERCISES[i].group === "Core Flexion" || ALL_EXERCISES[i].group === "Core Stability" ? "Core" : ALL_EXERCISES[i].group)
    ).size;

    return (
      <div style={{ display: "flex", gap: 40, padding: 32, minHeight: "100vh", background: "#0A0A0B", fontFamily: "-apple-system, 'SF Pro Display', 'Helvetica Neue', sans-serif", color: "#fff", justifyContent: "center", flexWrap: "wrap" }}>
        <div style={{ width: 375 }}>
          <div style={{ fontSize: 11, textTransform: "uppercase", letterSpacing: 2, color: "#555", marginBottom: 12, fontWeight: 600 }}>iPhone — Enrolment</div>
          <div style={{ width: 375, height: 812, background: "#111113", borderRadius: 44, border: "3px solid #2A2A2E", overflow: "hidden", display: "flex", flexDirection: "column" }}>
            <div style={{ height: 54 }} />
            <div style={{ flex: 1, overflow: "auto", padding: "0 20px" }}>
              <div style={{ fontSize: 28, fontWeight: 700, marginTop: 8 }}>Choose Your Program</div>
              <div style={{ fontSize: 14, color: "#888", marginTop: 4, marginBottom: 6 }}>Select the exercises you want to train</div>
              {groupCount >= 4 ? (
                <div style={{ fontSize: 12, color: "#16A34A", marginBottom: 16 }}>✓ All muscle groups covered</div>
              ) : groupCount > 0 ? (
                <div style={{ fontSize: 12, color: "#D4A017", marginBottom: 16 }}>
                  {4 - groupCount} muscle group{4 - groupCount > 1 ? "s" : ""} not covered — add more for balanced training
                </div>
              ) : (
                <div style={{ fontSize: 12, color: "#555", marginBottom: 16 }}>Pick at least one to get started</div>
              )}

              {groups.map(g => (
                <div key={g.label} style={{ marginBottom: 16 }}>
                  <div style={{ fontSize: 11, textTransform: "uppercase", letterSpacing: 1.5, color: "#555", fontWeight: 600, marginBottom: 8 }}>{g.label}</div>
                  {g.indices.map(i => {
                    const ex = ALL_EXERCISES[i];
                    const on = enrolled.has(i);
                    return (
                      <div key={i} onClick={() => toggleEnrol(i)} style={{
                        background: on ? ex.color + "18" : "#18181B",
                        borderRadius: 14, padding: "14px 16px", marginBottom: 8, cursor: "pointer",
                        border: `2px solid ${on ? ex.color : "#2A2A2E"}`, transition: "all 0.2s",
                      }}>
                        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                          <div style={{ width: 40, height: 40, borderRadius: 12, background: ex.color + "22", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 20 }}>{ex.icon}</div>
                          <div style={{ flex: 1 }}>
                            <div style={{ fontWeight: 600, fontSize: 16 }}>{ex.name}</div>
                            <div style={{ fontSize: 12, color: "#888", marginTop: 2 }}>
                              3 levels · ~{ex.name === "Pull-Ups" ? "19" : ex.name === "Push-Ups" ? "18" : "15"} weeks
                            </div>
                          </div>
                          <div style={{
                            width: 28, height: 28, borderRadius: 14, border: `2px solid ${on ? ex.color : "#444"}`,
                            background: on ? ex.color : "transparent", display: "flex", alignItems: "center", justifyContent: "center",
                            fontSize: 14, color: "#fff", transition: "all 0.2s",
                          }}>
                            {on && "✓"}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              ))}
            </div>
            <div style={{ padding: "12px 20px 36px" }}>
              <button onClick={() => enrolled.size > 0 && setAppState("main")} style={{
                width: "100%", padding: "16px", borderRadius: 14, border: "none", fontSize: 16, fontWeight: 600, cursor: enrolled.size > 0 ? "pointer" : "default",
                background: enrolled.size > 0 ? "#fff" : "#333", color: enrolled.size > 0 ? "#000" : "#666", transition: "all 0.2s",
              }}>
                {enrolled.size === 0 ? "Select at least one exercise" : `Start Program — ${enrolled.size} exercise${enrolled.size > 1 ? "s" : ""}`}
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // --- MAIN APP ---
  return (
    <div style={{ display: "flex", gap: 40, padding: 32, minHeight: "100vh", background: "#0A0A0B", fontFamily: "-apple-system, 'SF Pro Display', 'Helvetica Neue', sans-serif", color: "#fff", justifyContent: "center", flexWrap: "wrap" }}>

      {/* iPhone */}
      <div style={{ width: 375, flexShrink: 0 }}>
        <div style={{ fontSize: 11, textTransform: "uppercase", letterSpacing: 2, color: "#555", marginBottom: 12, fontWeight: 600 }}>iPhone</div>
        <div style={{ width: 375, height: 812, background: "#111113", borderRadius: 44, border: "3px solid #2A2A2E", overflow: "hidden", position: "relative", display: "flex", flexDirection: "column" }}>
          <div style={{ height: 54, display: "flex", alignItems: "flex-end", justifyContent: "center", paddingBottom: 8, fontSize: 12, color: "#888", fontWeight: 600 }}>
            {screen === "today" ? "Today" : screen === "workout" ? ALL_EXERCISES[activeEx]?.name : screen === "program" ? "Program" : "History"}
          </div>

          <div style={{ flex: 1, overflow: "auto", padding: "0 20px" }}>

            {/* TODAY */}
            {screen === "today" && !showTest && (
              <div>
                <div style={{ fontSize: 28, fontWeight: 700, marginTop: 8 }}>Thursday</div>
                <div style={{ fontSize: 15, color: "#888", marginTop: 2, marginBottom: 20 }}>
                  {exercises.filter((_, i) => !completed.has(ALL_EXERCISES.indexOf(exercises[i]))).length} of {exercises.length} exercises due
                </div>

                {exercises.map((ex, i) => {
                  const realIdx = ALL_EXERCISES.indexOf(ex);
                  const done = completed.has(realIdx);
                  return (
                    <div key={realIdx} onClick={() => !done && startEx(realIdx)} style={{
                      background: done ? "#1A1A1D" : "#18181B", borderRadius: 16, padding: "16px 18px", marginBottom: 10,
                      cursor: done ? "default" : "pointer", opacity: done ? 0.5 : 1,
                      border: `1px solid ${done ? "#222" : ex.warning ? ex.color + "44" : "#2A2A2E"}`,
                      transition: "all 0.2s", position: "relative",
                    }}>
                      {ex.warning && !done && (
                        <div style={{ fontSize: 11, color: "#D4A017", marginBottom: 8, display: "flex", alignItems: "center", gap: 6 }}>
                          <span style={{ fontSize: 13 }}>⚠️</span> {ex.warning}
                        </div>
                      )}
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                          <div style={{ width: 36, height: 36, borderRadius: 10, background: ex.color + "22", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 18 }}>
                            {done ? "✓" : ex.icon}
                          </div>
                          <div>
                            <div style={{ fontWeight: 600, fontSize: 16 }}>{ex.name}</div>
                            <div style={{ fontSize: 12, color: "#666", marginTop: 2 }}>
                              L{ex.level} · Day {ex.day} of {ex.totalDays}
                              <span style={{ color: "#444", marginLeft: 6 }}>{ex.group}</span>
                            </div>
                          </div>
                        </div>
                        <div style={{ textAlign: "right" }}>
                          <div style={{ fontSize: 14, fontWeight: 600, color: ex.color }}>{ex.total}</div>
                          <div style={{ fontSize: 11, color: "#555" }}>{ex.sets.length} sets</div>
                        </div>
                      </div>
                      {!done && (
                        <div style={{ display: "flex", gap: 6, marginTop: 10 }}>
                          {ex.sets.map((s, j) => (
                            <div key={j} style={{ flex: 1, background: "#252528", borderRadius: 6, padding: "4px 0", textAlign: "center", fontSize: 13, fontWeight: 500, color: "#AAA", fontVariantNumeric: "tabular-nums" }}>{s}</div>
                          ))}
                        </div>
                      )}
                    </div>
                  );
                })}

                <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
                  <div onClick={() => setShowTest(true)} style={{ flex: 1, padding: "12px 0", borderRadius: 12, background: "#1A1A1D", border: "1px dashed #333", textAlign: "center", cursor: "pointer", fontSize: 12, color: "#666" }}>
                    Test day →
                  </div>
                  <div onClick={() => setAppState("enrol")} style={{ flex: 1, padding: "12px 0", borderRadius: 12, background: "#1A1A1D", border: "1px dashed #333", textAlign: "center", cursor: "pointer", fontSize: 12, color: "#666" }}>
                    ← Enrolment
                  </div>
                </div>
              </div>
            )}

            {/* TEST DAY */}
            {screen === "today" && showTest && (
              <div style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", height: "100%", textAlign: "center", paddingBottom: 80 }}>
                <div style={{ fontSize: 14, textTransform: "uppercase", letterSpacing: 3, color: TEST_EXERCISE.color, fontWeight: 700, marginBottom: 8 }}>Level {TEST_EXERCISE.level} Final</div>
                <div style={{ fontSize: 32, fontWeight: 700 }}>{TEST_EXERCISE.name} Test</div>
                <div style={{ margin: "32px 0" }}>
                  <svg width="200" height="200" viewBox="0 0 200 200">
                    <circle cx="100" cy="100" r="88" fill="none" stroke="#222" strokeWidth="6" />
                    <circle cx="100" cy="100" r="88" fill="none" stroke={TEST_EXERCISE.color} strokeWidth="6"
                      strokeDasharray={`${(testReps / TEST_EXERCISE.target) * 553} 553`}
                      strokeLinecap="round" transform="rotate(-90 100 100)" style={{ transition: "stroke-dasharray 0.3s" }} />
                    <text x="100" y="92" textAnchor="middle" fill="white" fontSize="56" fontWeight="700" fontFamily="SF Mono, monospace">{testReps}</text>
                    <text x="100" y="118" textAnchor="middle" fill="#666" fontSize="16">of {TEST_EXERCISE.target}</text>
                  </svg>
                </div>
                {!testDone ? (
                  <>
                    <div style={{ display: "flex", gap: 12 }}>
                      <button onClick={() => setTestReps(r => Math.max(0, r - 1))} style={{ width: 56, height: 56, borderRadius: 28, background: "#222", border: "none", color: "#fff", fontSize: 24, cursor: "pointer" }}>−</button>
                      <button onClick={() => { const n = testReps + 1; setTestReps(n); if (n >= TEST_EXERCISE.target) setTestDone(true); }}
                        style={{ width: 56, height: 56, borderRadius: 28, background: TEST_EXERCISE.color, border: "none", color: "#fff", fontSize: 24, cursor: "pointer" }}>+</button>
                    </div>
                    <button onClick={() => setTestDone(true)} style={{ marginTop: 24, padding: "10px 32px", borderRadius: 12, background: "#222", border: "none", color: "#aaa", fontSize: 14, cursor: "pointer" }}>End Test</button>
                  </>
                ) : (
                  <div style={{ marginTop: 8 }}>
                    {testReps >= TEST_EXERCISE.target ? (
                      <>
                        <div style={{ fontSize: 48, marginBottom: 8 }}>🎉</div>
                        <div style={{ fontSize: 20, fontWeight: 700, color: TEST_EXERCISE.color }}>Level {TEST_EXERCISE.level + 1} Unlocked!</div>
                        <div style={{ fontSize: 14, color: "#888", marginTop: 8 }}>{testReps} reps — target smashed</div>
                      </>
                    ) : (
                      <>
                        <div style={{ fontSize: 20, fontWeight: 600 }}>Almost there</div>
                        <div style={{ fontSize: 14, color: "#888", marginTop: 8 }}>{testReps} of {TEST_EXERCISE.target} — {TEST_EXERCISE.target - testReps} short</div>
                        <div style={{ fontSize: 13, color: "#555", marginTop: 4 }}>Retry next scheduled day after rest</div>
                      </>
                    )}
                    <button onClick={() => { setShowTest(false); setTestReps(0); setTestDone(false); }}
                      style={{ marginTop: 20, padding: "10px 32px", borderRadius: 12, background: "#222", border: "none", color: "#fff", fontSize: 14, cursor: "pointer" }}>Back to Today</button>
                  </div>
                )}
              </div>
            )}

            {/* WORKOUT SESSION */}
            {screen === "workout" && activeEx !== null && (
              <div style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", height: "100%", paddingBottom: 80 }}>
                {!exDone ? (
                  resting ? (
                    <>
                      <div style={{ fontSize: 13, textTransform: "uppercase", letterSpacing: 2, color: "#666" }}>Rest — {ALL_EXERCISES[activeEx].rest}s</div>
                      <div style={{ fontSize: 80, fontWeight: 700, fontVariantNumeric: "tabular-nums", fontFamily: "SF Mono, ui-monospace, monospace", color: restTime <= 10 ? ALL_EXERCISES[activeEx].color : "#fff" }}>
                        {fmt(restTime)}
                      </div>
                      <div style={{ marginTop: 24, fontSize: 14, color: "#555" }}>Next: Set {currentSet + 1} — {ALL_EXERCISES[activeEx].sets[currentSet]} reps</div>
                      <div style={{ display: "flex", gap: 8, marginTop: 20 }}>
                        {ALL_EXERCISES[activeEx].sets.map((_, j) => (
                          <div key={j} style={{ width: 8, height: 8, borderRadius: 4, background: j < currentSet ? ALL_EXERCISES[activeEx].color : j === currentSet ? "#fff" : "#333" }} />
                        ))}
                      </div>
                      <button onClick={() => { setResting(false); setRestTime(ALL_EXERCISES[activeEx].rest); }} style={{ marginTop: 32, padding: "10px 32px", borderRadius: 12, background: "#222", border: "none", color: "#fff", fontSize: 14, cursor: "pointer" }}>Skip Rest</button>
                    </>
                  ) : ALL_EXERCISES[activeEx].mode === "confirm" ? (
                    /* POST-SET CONFIRMATION MODE (Push-Ups, Pull-Ups, Sit-Ups) */
                    setPhase === "ready" ? (
                      <>
                        <div style={{ fontSize: 13, textTransform: "uppercase", letterSpacing: 2, color: ALL_EXERCISES[activeEx].color, fontWeight: 600 }}>
                          Set {currentSet + 1} of {ALL_EXERCISES[activeEx].sets.length}
                        </div>
                        <div style={{ fontSize: 56, fontWeight: 700, marginTop: 16, color: "#888" }}>{ALL_EXERCISES[activeEx].sets[currentSet]}</div>
                        <div style={{ fontSize: 14, color: "#555", marginTop: 4 }}>reps target</div>
                        <div style={{ display: "flex", gap: 8, marginTop: 20 }}>
                          {ALL_EXERCISES[activeEx].sets.map((_, j) => (
                            <div key={j} style={{ width: 8, height: 8, borderRadius: 4, background: j < currentSet ? ALL_EXERCISES[activeEx].color : j === currentSet ? "#fff" : "#333" }} />
                          ))}
                        </div>
                        <button onClick={() => { setSetPhase("active"); setElapsed(0); }}
                          style={{ marginTop: 32, padding: "16px 56px", borderRadius: 16, background: ALL_EXERCISES[activeEx].color, border: "none", color: "#fff", fontSize: 18, fontWeight: 700, cursor: "pointer" }}>
                          Start Set
                        </button>
                        <div style={{ fontSize: 11, color: "#444", marginTop: 12 }}>Put your phone down and go</div>
                      </>
                    ) : setPhase === "active" ? (
                      <>
                        <div style={{ fontSize: 13, textTransform: "uppercase", letterSpacing: 2, color: ALL_EXERCISES[activeEx].color, fontWeight: 600 }}>
                          Set {currentSet + 1} — In Progress
                        </div>
                        <div style={{ width: 120, height: 120, borderRadius: 60, border: `4px solid ${ALL_EXERCISES[activeEx].color}`, display: "flex", alignItems: "center", justifyContent: "center", marginTop: 24 }}>
                          <div style={{ fontSize: 40, fontWeight: 700, fontFamily: "SF Mono, ui-monospace, monospace", fontVariantNumeric: "tabular-nums" }}>{fmt(elapsed)}</div>
                        </div>
                        <div style={{ fontSize: 14, color: "#555", marginTop: 16 }}>Target: {ALL_EXERCISES[activeEx].sets[currentSet]} reps</div>
                        <div style={{ width: 8, height: 8, borderRadius: 4, background: ALL_EXERCISES[activeEx].color, marginTop: 16, animation: "pulse 1.5s infinite" }} />
                        <button onClick={() => { setSetPhase("confirm"); setReps(ALL_EXERCISES[activeEx].sets[currentSet]); }}
                          style={{ marginTop: 32, padding: "14px 48px", borderRadius: 14, background: "#333", border: "none", color: "#fff", fontSize: 16, fontWeight: 600, cursor: "pointer" }}>
                          End Set
                        </button>
                      </>
                    ) : (
                      /* confirm phase - enter actual reps */
                      <>
                        <div style={{ fontSize: 13, textTransform: "uppercase", letterSpacing: 2, color: "#888" }}>
                          How many did you do?
                        </div>
                        <div style={{ fontSize: 96, fontWeight: 700, marginTop: 8, fontVariantNumeric: "tabular-nums", fontFamily: "SF Mono, ui-monospace, monospace" }}>{reps}</div>
                        <div style={{ fontSize: 14, color: "#555", marginTop: -4 }}>target was {ALL_EXERCISES[activeEx].sets[currentSet]}</div>
                        <div style={{ display: "flex", gap: 16, marginTop: 24 }}>
                          <button onClick={() => setReps(r => Math.max(0, r - 1))} style={{ width: 64, height: 64, borderRadius: 32, background: "#222", border: "none", color: "#fff", fontSize: 28, cursor: "pointer" }}>−</button>
                          <button onClick={() => setReps(r => r + 1)} style={{ width: 64, height: 64, borderRadius: 32, background: ALL_EXERCISES[activeEx].color, border: "none", color: "#fff", fontSize: 28, cursor: "pointer" }}>+</button>
                        </div>
                        <button onClick={doneSet} style={{
                          marginTop: 24, padding: "14px 48px", borderRadius: 14, border: "none", color: "#fff", fontSize: 16, fontWeight: 600, cursor: "pointer",
                          background: ALL_EXERCISES[activeEx].color, transition: "background 0.3s",
                        }}>Confirm</button>
                      </>
                    )
                  ) : (
                    /* REAL-TIME COUNTING MODE (Squats, Glute Bridges, Dead Bugs) */
                    <>
                      <div style={{ fontSize: 13, textTransform: "uppercase", letterSpacing: 2, color: ALL_EXERCISES[activeEx].color, fontWeight: 600 }}>
                        Set {currentSet + 1} of {ALL_EXERCISES[activeEx].sets.length}
                      </div>
                      <div style={{ fontSize: 96, fontWeight: 700, marginTop: 8, fontVariantNumeric: "tabular-nums", fontFamily: "SF Mono, ui-monospace, monospace" }}>{reps}</div>
                      <div style={{ fontSize: 16, color: "#555", marginTop: -4 }}>of {ALL_EXERCISES[activeEx].sets[currentSet]}</div>
                      <div style={{ display: "flex", gap: 16, marginTop: 32 }}>
                        <button onClick={() => setReps(r => Math.max(0, r - 1))} style={{ width: 64, height: 64, borderRadius: 32, background: "#222", border: "none", color: "#fff", fontSize: 28, cursor: "pointer" }}>−</button>
                        <button onClick={() => setReps(r => r + 1)} style={{ width: 64, height: 64, borderRadius: 32, background: ALL_EXERCISES[activeEx].color, border: "none", color: "#fff", fontSize: 28, cursor: "pointer" }}>+</button>
                      </div>
                      <button onClick={doneSet} style={{
                        marginTop: 32, padding: "14px 48px", borderRadius: 14, border: "none", color: "#fff", fontSize: 16, fontWeight: 600, cursor: "pointer",
                        background: reps >= ALL_EXERCISES[activeEx].sets[currentSet] ? ALL_EXERCISES[activeEx].color : "#333", transition: "background 0.3s",
                      }}>Done</button>
                      <div style={{ display: "flex", gap: 8, marginTop: 24 }}>
                        {ALL_EXERCISES[activeEx].sets.map((_, j) => (
                          <div key={j} style={{ width: 8, height: 8, borderRadius: 4, background: j < currentSet ? ALL_EXERCISES[activeEx].color : j === currentSet ? "#fff" : "#333" }} />
                        ))}
                      </div>
                    </>
                  )
                ) : (
                  <>
                    <div style={{ width: 64, height: 64, borderRadius: 32, background: ALL_EXERCISES[activeEx].color + "22", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 28, marginBottom: 16 }}>✓</div>
                    <div style={{ fontSize: 24, fontWeight: 700 }}>{ALL_EXERCISES[activeEx].name}</div>
                    <div style={{ fontSize: 16, color: "#888", marginTop: 4 }}>{ALL_EXERCISES[activeEx].total} reps complete</div>
                    <div style={{ fontSize: 13, color: "#555", marginTop: 2 }}>+12 reps vs last session</div>

                    {remaining.length > 0 && (
                      <div style={{ marginTop: 28, width: "100%" }}>
                        <div style={{ fontSize: 12, color: "#555", textTransform: "uppercase", letterSpacing: 1, marginBottom: 8 }}>{remaining.length} exercise{remaining.length > 1 ? "s" : ""} remaining</div>
                        {remaining.slice(0, 3).map(ex => (
                          <div key={ex.name} style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 0", borderBottom: "1px solid #1E1E20" }}>
                            <div style={{ width: 8, height: 8, borderRadius: 4, background: ex.color }} />
                            <div style={{ fontSize: 14, flex: 1 }}>{ex.name}</div>
                            <div style={{ fontSize: 12, color: "#555" }}>{ex.sets.length} sets</div>
                          </div>
                        ))}
                      </div>
                    )}

                    <button onClick={() => { setScreen("today"); setActiveEx(null); setExDone(false); }}
                      style={{ marginTop: 28, padding: "14px 48px", borderRadius: 14, background: "#222", border: "none", color: "#fff", fontSize: 16, fontWeight: 600, cursor: "pointer" }}>
                      Back to Today
                    </button>
                  </>
                )}
              </div>
            )}

            {/* PROGRAM */}
            {screen === "program" && (
              <div>
                <div style={{ fontSize: 28, fontWeight: 700, marginTop: 8, marginBottom: 20 }}>Program</div>
                {exercises.map((ex) => (
                  <Card key={ex.name} style={{ padding: "16px 18px", marginBottom: 10 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 12 }}>
                      <div style={{ width: 36, height: 36, borderRadius: 10, background: ex.color + "22", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 18 }}>{ex.icon}</div>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontWeight: 600, fontSize: 16 }}>{ex.name}</div>
                        <div style={{ fontSize: 12, color: "#666", marginTop: 1 }}>Level {ex.level} · Day {ex.day} of {ex.totalDays}</div>
                      </div>
                      <div style={{ fontSize: 11, color: "#555" }}>{ex.group}</div>
                    </div>
                    <div style={{ display: "flex", gap: 4 }}>
                      {[1, 2, 3].map(l => (
                        <div key={l} style={{
                          flex: 1, height: 6, borderRadius: 3,
                          background: l < ex.level ? ex.color : l === ex.level ? "#333" : "#222",
                          backgroundImage: l === ex.level ? `linear-gradient(to right, ${ex.color} ${(ex.day / ex.totalDays) * 100}%, #333 ${(ex.day / ex.totalDays) * 100}%)` : undefined,
                        }} />
                      ))}
                    </div>
                    <div style={{ display: "flex", justifyContent: "space-between", marginTop: 8, fontSize: 11, color: "#555" }}>
                      <span>{ex.level > 1 ? "L1 ✓" : "L1"}</span>
                      <span style={{ color: ex.level === 2 ? ex.color : "#555" }}>{ex.level === 2 ? "In progress" : ex.level > 2 ? "✓" : "Locked"}</span>
                      <span>{ex.level < 3 ? "Locked" : "In progress"}</span>
                    </div>
                  </Card>
                ))}
              </div>
            )}

            {/* HISTORY */}
            {screen === "history" && (
              <div>
                <div style={{ fontSize: 28, fontWeight: 700, marginTop: 8 }}>History</div>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10, margin: "20px 0" }}>
                  {[{ label: "Total Reps", value: "12,847" }, { label: "Streak", value: "18 days" }, { label: "Sessions", value: "42" }].map((s, i) => (
                    <Card key={i} style={{ padding: 14, textAlign: "center" }}>
                      <div style={{ fontSize: 20, fontWeight: 700 }}>{s.value}</div>
                      <div style={{ fontSize: 11, color: "#666", marginTop: 2 }}>{s.label}</div>
                    </Card>
                  ))}
                </div>
                {["Today", "Yesterday", "Mon 10 Mar", "Sat 8 Mar", "Thu 6 Mar"].map((day, i) => (
                  <Card key={i} style={{ padding: "14px 16px", marginBottom: 8 }}>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                      <div>
                        <div style={{ fontWeight: 600, fontSize: 15 }}>{day}</div>
                        <div style={{ fontSize: 12, color: "#666", marginTop: 2 }}>
                          {exercises.length - i > 0 ? exercises.length - i : 1} exercises · {[498, 462, 510, 445, 389][i]} reps
                        </div>
                      </div>
                      <div style={{ display: "flex", gap: 4 }}>
                        {exercises.slice(0, exercises.length - i > 0 ? exercises.length - i : 1).map((ex, j) => (
                          <div key={j} style={{ width: 6, height: 6, borderRadius: 3, background: ex.color }} />
                        ))}
                      </div>
                    </div>
                  </Card>
                ))}
                {completed.size < exercises.length && (
                  <Card style={{ padding: "12px 16px", marginBottom: 8, borderStyle: "dashed" }}>
                    <div style={{ fontSize: 13, color: "#666" }}>
                      📋 {exercises.length - completed.size} exercise{exercises.length - completed.size > 1 ? "s" : ""} pushed to tomorrow
                    </div>
                  </Card>
                )}
              </div>
            )}
          </div>

          {/* Tab bar */}
          {screen !== "workout" && (
            <div style={{ height: 82, background: "#111113", borderTop: "1px solid #222", display: "flex", justifyContent: "space-around", alignItems: "flex-start", paddingTop: 10 }}>
              {[{ id: "today", label: "Today", icon: "📋" }, { id: "program", label: "Program", icon: "📊" }, { id: "history", label: "History", icon: "📈" }].map(tab => (
                <div key={tab.id} onClick={() => { setScreen(tab.id); setShowTest(false); }}
                  style={{ textAlign: "center", cursor: "pointer", opacity: screen === tab.id ? 1 : 0.4 }}>
                  <div style={{ fontSize: 22 }}>{tab.icon}</div>
                  <div style={{ fontSize: 10, marginTop: 2, fontWeight: 500 }}>{tab.label}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Apple Watch */}
      <div style={{ width: 198, flexShrink: 0 }}>
        <div style={{ fontSize: 11, textTransform: "uppercase", letterSpacing: 2, color: "#555", marginBottom: 12, fontWeight: 600 }}>Apple Watch — Companion</div>
        <div style={{ width: 198, height: 242, background: "#111113", borderRadius: 48, border: "3px solid #2A2A2E", overflow: "hidden", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>

          {watchView === "today" && (
            <div style={{ textAlign: "center", padding: "0 16px", width: "100%" }}>
              <div style={{ fontSize: 10, color: "#888", marginBottom: 8 }}>TODAY</div>
              {exercises.slice(0, 4).map((ex, i) => (
                <div key={i} onClick={() => setWatchView("set")} style={{ display: "flex", alignItems: "center", gap: 8, padding: "6px 0", borderBottom: "1px solid #1E1E20", cursor: "pointer" }}>
                  <div style={{ width: 6, height: 6, borderRadius: 3, background: ex.color }} />
                  <div style={{ fontSize: 12, flex: 1, textAlign: "left" }}>{ex.name}</div>
                  <div style={{ fontSize: 10, color: "#555" }}>{ex.sets.length}s</div>
                </div>
              ))}
              {exercises.length > 4 && <div style={{ fontSize: 10, color: "#555", marginTop: 6 }}>+{exercises.length - 4} more</div>}
            </div>
          )}

          {watchView === "set" && (
            <div style={{ textAlign: "center", cursor: "pointer" }} onClick={() => { setWatchReps(r => r + 1); if (watchReps + 1 >= 34) setWatchView("rest"); }}>
              <div style={{ fontSize: 9, textTransform: "uppercase", letterSpacing: 1.5, color: "#E8722A", fontWeight: 600 }}>Set 1 of 5</div>
              <div style={{ fontSize: 64, fontWeight: 700, lineHeight: 1, marginTop: 4, fontFamily: "SF Mono, ui-monospace, monospace", fontVariantNumeric: "tabular-nums" }}>{watchReps}</div>
              <div style={{ fontSize: 13, color: "#555", marginTop: 2 }}>of 34</div>
              <div style={{ display: "flex", gap: 4, justifyContent: "center", marginTop: 12 }}>
                {[0,1,2,3,4].map(i => <div key={i} style={{ width: 5, height: 5, borderRadius: 3, background: i === 0 ? "#fff" : "#333" }} />)}
              </div>
              <div style={{ fontSize: 9, color: "#444", marginTop: 8 }}>Tap to count · Crown ±</div>
            </div>
          )}

          {watchView === "rest" && (
            <div style={{ textAlign: "center", cursor: "pointer" }} onClick={() => setWatchView("done")}>
              <div style={{ fontSize: 9, textTransform: "uppercase", letterSpacing: 1.5, color: "#666" }}>Rest</div>
              <div style={{ fontSize: 52, fontWeight: 700, lineHeight: 1, marginTop: 4, fontFamily: "SF Mono, ui-monospace, monospace" }}>0:47</div>
              <div style={{ fontSize: 11, color: "#555", marginTop: 8 }}>Next: Set 2 — 24 reps</div>
              <div style={{ fontSize: 9, color: "#444", marginTop: 8 }}>Tap to skip</div>
            </div>
          )}

          {watchView === "done" && (
            <div style={{ textAlign: "center", cursor: "pointer" }} onClick={() => { setWatchView("today"); setWatchReps(0); }}>
              <div style={{ fontSize: 32, marginBottom: 4 }}>✓</div>
              <div style={{ fontSize: 15, fontWeight: 700 }}>Push-Ups</div>
              <div style={{ fontSize: 12, color: "#888", marginTop: 2 }}>118 reps</div>
              <div style={{ marginTop: 12, fontSize: 11, color: "#555" }}>5 exercises remaining</div>
              <div style={{ fontSize: 10, color: "#E8722A", marginTop: 4, fontWeight: 600 }}>Back to today →</div>
            </div>
          )}
        </div>

        <div style={{ display: "flex", gap: 6, marginTop: 12, flexWrap: "wrap" }}>
          {["today", "set", "rest", "done"].map(s => (
            <button key={s} onClick={() => { setWatchView(s); setWatchReps(0); }}
              style={{ flex: "1 0 40%", padding: "6px 0", borderRadius: 8, background: watchView === s ? "#333" : "#1A1A1D", border: "1px solid #2A2A2E", color: watchView === s ? "#fff" : "#666", fontSize: 10, cursor: "pointer", textTransform: "capitalize" }}>
              {s}
            </button>
          ))}
        </div>

        {/* Complications */}
        <div style={{ marginTop: 20 }}>
          <div style={{ fontSize: 11, textTransform: "uppercase", letterSpacing: 2, color: "#555", marginBottom: 8, fontWeight: 600 }}>Complications</div>
          <div style={{ display: "flex", gap: 8 }}>
            <div style={{ width: 52, height: 52, borderRadius: 14, background: "#18181B", border: "1px solid #2A2A2E", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
              <div style={{ fontSize: 8, color: "#666" }}>DUE</div>
              <div style={{ fontSize: 16, fontWeight: 700 }}>{completed.size}/{exercises.length}</div>
            </div>
            <div style={{ width: 52, height: 52, borderRadius: 14, background: "#18181B", border: "1px solid #2A2A2E", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
              <div style={{ fontSize: 8, color: "#16A34A" }}>REST</div>
              <div style={{ fontSize: 10, fontWeight: 600, color: "#888" }}>DAY</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
