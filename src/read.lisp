
(in-package #:wordnet-dsl)

(defparameter *comment-char* #\;)

(defparameter *pointers* '(("n" . (("!" "ant" "Antonym")
                                   ("@" "hyper" "Hypernym")
                                   ("@i" "ihyper" "Instance Hypernym")
                                   ("~" "hypo" "Hyponym")
                                   ("~i" "ihypo" "Instance Hyponym")
                                   ("#m" "hm" "Member holonym")
                                   ("#s" "hs" "Substance holonym")
                                   ("#p" "hp" "Part holonym")
                                   ("%m" "mm" "Member meronym")
                                   ("%s" "ms" "Substance meronym")
                                   ("%p" "mp" "Part meronym")
                                   ("=" "attr" "Attribute")
                                   ("+" "drf" "Derivationally related form")
                                   (";c" "dt" "Domain of synset - TOPIC")
                                   ("-c" "mt" "Member of this domain - TOPIC")
                                   (";r" "dr" "Domain of synset - REGION")
                                   ("-r" "mr" "Member of this domain - REGION")
                                   (";u" "du" "Domain of synset - USAGE")
                                   ("-u" "mu" "Member of this domain - USAGE")))
                           ("v" . (("!" "ant" "Antonym")
                                   ("@" "hyper" "Hypernym")
                                   ("~" "hypo" "Hyponym")
                                   ("*" "entail" "entailment")
                                   (">" "cause" "Cause")
                                   ("^" "see" "Also see")
                                   ("$" "vg" "Verb Group")
                                   ("+" "drf" "Derivationally related form")
                                   (";c" "dt" "Domain of synset - TOPIC")
                                   (";r" "dr" "Domain of synset - REGION")
                                   (";u" "du" "Domain of synset - USAGE")))
                           ("a" . (("!" "ant" "Antonym")
                                   ("&" "sim" "Similar to")
                                   ("<" "pv" "Participle of verb")
                                   ("\\" "pe" "Pertainym (pertains to noun)")
                                   ("=" "attr" "Attribute")
                                   ("^" "see" "Also see")
                                   ("+" "drf" "Derivationally related form")
                                   (";c" "dt" "Domain of synset - TOPIC")
                                   (";r" "dr" "Domain of synset - REGION")
                                   (";u" "du" "Domain of synset - USAGE")))
                           ("s" . (("!" "ant" "Antonym")
                                   ("&" "sim" "Similar to")
                                   ("<" "pv" "Participle of verb")
                                   ("\\" "pe" "Pertainym (pertains to noun)")
                                   ("=" "attr" "Attribute")
                                   ("^" "see" "Also see")
                                   ("+" "drf" "Derivationally related form")
                                   (";c" "dt" "Domain of synset - TOPIC")
                                   (";r" "dr" "Domain of synset - REGION")
                                   (";u" "du" "Domain of synset - USAGE")))
                           ("r" . (("!" "ant" "Antonym")
                                   ("\\" "da" "Derived from adjective")
                                   (";c" "dt" "Domain of synset - TOPIC")
                                   (";r" "dr" "Domain of synset - REGION")
                                   (";u" "du" "Domain of synset - USAGE")))))

(defparameter *pos* '(("noun" . "n") 
                      ("verb" . "v") 
                      ("adj"  . "a") 
                      ("adjs" . "a")
                      ("adv"  . "r")))

(defparameter *pointers-ids* (loop for p in *pointers*
				   append (mapcar #'cadr (cdr p))))



(defun read-wn (path-with-wildcard)
  (let ((idx (make-hash-table :test #'equal)))
    (dolist (fn (directory path-with-wildcard) idx)
      (dolist (ss (read-synsets fn))
	(index-synset ss idx)))))


(defun index-synset (synset idx)
  "For each synset. A sense is a cons (sense-id, word) and a pointer
   is a list (source, link, target) where source can be zero for a
   semantic pointer or an sense-id for a syntatic pointer."
  (dolist (pointer (synset-pointers synset))
    (destructuring-bind (source link target)
	pointer
      (if (null (gethash target idx))
	  (setf (gethash target idx) (cons nil 1))
	  (incf (cdr (gethash target idx))))))
  (dolist (sense (synset-senses synset))
    (cond
      ((null (gethash (car sense) idx))
       (setf (gethash (car sense) idx)
	     (cons synset 0)))
      ((null (car (gethash (car sense) idx)))
       (setf (gethash (car sense) idx)
	     (cons synset (cdr (gethash (car sense) idx)))))
      (t (error "Invalid duplication ~a" synset)))))


(defun merge-lines (lines &optional (res nil))
  (labels ((++ (s1 s2)
	     (concatenate 'string s1 s2)))
    (cond
      ((null lines)
       (reverse res))
      ((cl-ppcre:scan (format nil "^~a" *comment-char*) (car lines))
       (merge-lines (cdr lines) res))
      ((cl-ppcre:scan "^ " (car lines))
       (merge-lines (cdr lines) (cons (++ (car res) (car lines)) (cdr res))))
      (t 
       (merge-lines (cdr lines) (cons (car lines) res))))))


(defun read-synsets (filename)
  (with-open-file (stream filename)
    (macrolet ((flush-line ()
		 `(setq line (read-line stream nil nil)
			lineno (+ lineno 1))))
      (prog ((synsets nil) begining line lines (lineno 0))
       label-1
       (flush-line)
       (alexandria:switch (line :test #'equal)
	 (nil (go label-3))
	 (""  (go label-1))
	 (t (setq begining lineno)
	    (push line lines)
	    (go label-2)))
       
       label-2
       (flush-line)
       (alexandria:switch (line :test #'equal)
	 (nil (go label-3))
	 (""  (push (make-synset filename begining (reverse lines)) synsets)
	      (setq lines nil)
	      (go label-1))
	 (t (push line lines)
	    (go label-2)))

       label-3
       (if lines
	   (push (make-synset filename begining (reverse lines)) synsets))
       (return synsets)))))


(defun word-key (filename word)
  (if (position #\: word)
      word
      (format nil "~a:~a" filename word)))

(defun word-lemma (word)
  (cond
    ((position #\" word)
     (subseq word 0 (position #\" word)))
    ((cl-ppcre:scan "[0-9]+$" word)
     (multiple-value-bind (s e rs re)
	 (cl-ppcre:scan "[0-9]+$" word)
       (declare (ignore rs re e))
       (subseq word 0 s)))
    (t word)))

(defun make-synset (filename lineno lines)
  (let* ((fn (pathname-name filename))
	 (lines1 (mapcar (lambda (l)
			   (let ((pos (position #\: l)))
			     (cons (string-trim '(#\Space #\Tab) (subseq l 0 pos))
				   (string-trim '(#\Space #\Tab) (subseq l (1+ pos) (length l))))))
			 (merge-lines lines)))
	 (ss (make-instance 'synset
			    :file fn
			    :line lineno
			    :lines lines1)))
    (dolist (l (synset-lines ss) ss)
      (cond
	((member (car l) *pointers-ids* :test #'equal)
	 (push (list 0 (car l) (word-key fn (cdr l)))
	       (synset-pointers ss)))
	((equal (car l) "w")
	 (let* ((tks (cl-ppcre:split "[ ]+" (cdr l)))
		(sense-key (word-key fn (car tks))))
	   (push (cons sense-key (word-lemma (car tks)))
		 (synset-senses ss))
	   (if (> (length tks) 1)
	       (loop for (link target) on (cdr tks) by #'cddr
		     until (equal "frame" link)
		     do (push (list sense-key
				    link
				    (word-key fn target))
			      (synset-pointers ss))))))))))



(defun add-properties (syn pattern slot)
  (mapcar (lambda (l)
	    (if (cl-ppcre:scan pattern l)
		(push (subseq l 2) (slot-value syn slot))))
	  (synset-lines syn))
  syn)


(defun add (line syn)
  (let ((infos (cl-ppcre:split "\\s+" line)))
    (cond ((equal "w:" (car infos))        (add-w syn infos))
	  ((equal "g:" (car infos))        (add-g syn line))
	  (T                               (add-rest syn infos)))))

(defun add-w (syn infos)
  (let* ((word-dirty (nth 1 infos))
	 (word (clean-word-1 word-dirty))
	 (sense (make-instance 'sense :word  word :id word-dirty)))
    (setf (synset-senses syn)
	  (append (synset-senses syn)
		  (list sense)))
    (add-w-rest sense (cddr infos))))

(defun clean-word-1 (word)
   (if (cl-ppcre:scan "[_a-z]*[a-z][1-9]$" word)
       (aref (nth 1 (multiple-value-list (cl-ppcre:scan-to-strings  "(.*)[1-9]$" word))) 0)
       word))
    

(defun add-w-rest (sense infos)
  (if (null infos)
      nil
      (let ((link (car infos)))
	(if (equal link "frame")
	    (let* ((separated (separate-for-frame (cdr infos)))
		   (target (make-target-for-frame (car separated))))
	      (setf (sense-links-targets sense)
		    (append (sense-links-targets sense)
			    (list link target)))
	      (add-w-rest sense (cadr separated)))
	    (let ((target (cadr infos)))
	      (setf (sense-links-targets sense)
		    (append (sense-links-targets sense)
			    (list link target)))
	      (add-w-rest sense (cddr infos)))))))
 
(defun add-g (syn line)
  (setf (synset-gloss syn)
	(aref (nth 1 (multiple-value-list (cl-ppcre:scan-to-strings  ": (.*)" line))) 0)))

(defun add-rest (syn infos)
  (let ((link (car infos)))
    (if (equal link "frame")
	(let ((target (make-target-for-frame (cdr infos))))
	  (setf (synset-pointers syn)
		(append (synset-pointers syn)
			(list link target)))
	  (setf (synset-slot-pointers syn)
		(append (synset-slot-pointers syn)
		       (list link))))
	(let ((target  (cadr infos)))
	  (setf (synset-pointers syn)
		(append (synset-pointers syn)
			(list link target)))
	  (setf (synset-slot-pointers syn)
		(append (synset-slot-pointers syn)
			(list link)))))))

(defun separate-for-frame (list &optional (number-list '()))
  (if (and (not (null list)) (cl-ppcre:scan  "^[0-9]*$" (car list)))
      (separate-for-frame (cdr  list) (append number-list (list (car list))))
      (list number-list list)))

(defun make-target-for-frame (list)
  (reduce #'(lambda (x y) (concatenate 'string x "-" y)) list))

(defun format-link (string)
  (substitute #\> #\] (substitute #\< #\[ string )))


;; testing and utilities

(defmacro with-open-files (args &body body)
  (case (length args)
    ((0)
     `(progn ,@body))
    ((1)
     `(with-open-file ,(first args) ,@body))
    (t `(with-open-file ,(first args)
	  (with-open-files
	      ,(rest args) ,@body)))))


(defun test ()
  (let ((idx (read-wn #P"/Users/arademaker/work/wordnet-dsl/dict/*.txt")))
    (maphash (lambda (k v)
	       (if (null (car v))
		   (error "invalid entry ~a ~a" k v)))
	     idx)))

(defun find-senses (lemma idx)
  (remove-if-not (lambda (ss)
		   (some (lambda (sense) (equal (cdr sense) lemma))
			 (synset-senses ss)))
		 (remove-duplicates (mapcar #'car (alexandria:hash-table-values idx)))))


(defun by-lemma (idx)
  (let ((dict (make-hash-table :test #'equal)))
    (dolist (ss (remove-duplicates (mapcar #'car (alexandria:hash-table-values idx))) dict)
      (dolist (sense (synset-senses ss))
	(if (gethash (cdr sense) dict nil)
	    (push (car sense)
		  (gethash (cdr sense) dict))
	    (setf (gethash (cdr sense) dict) (list (car sense))))))))


;; converting to ukb

(defun ukb-concept-id (sense-id)
  (destructuring-bind (fn localid)
      (cl-ppcre:split ":" sense-id)
    (destructuring-bind (pos lexname)
	(cl-ppcre:split "\\." fn)
      (format nil "~a/~a-~a" fn localid (cdr (assoc pos *pos* :test #'equal))))))


(defun synset-to-ukb (ss stream)
  (let ((default-sense (ukb-concept-id (caar (synset-senses ss)))))
    (dolist (p (synset-pointers ss))
      (format stream "u:~a v:~a d:0 w:1 s:own-en t:~a~%"
	      (if (equal 0 (car p)) default-sense (ukb-concept-id (car p)))
	      (ukb-concept-id (caddr p))
	      (cadr p)))
    (dolist (s (cdr (synset-senses ss)))
      (format stream "u:~a v:~a d:0 w:1 s:own-en t:syn~%"
	      default-sense
	      (ukb-concept-id (car s))))))


(defun convert-ukb (idx dict-file kb-file)
  (with-open-files ((sdt dict-file :direction :output :if-exists :supersede)
		    (skb   kb-file :direction :output :if-exists :supersede))
    (dolist (v (remove-duplicates (mapcar #'car (alexandria:hash-table-values idx))))
      (synset-to-ukb v skb))
    (maphash (lambda (k v)
	       (format sdt "~a ~{~a:1~^ ~}~%" k (mapcar #'ukb-concept-id v)))
	     (by-lemma idx))))
